# Offline cache migration for the lanis app

Status: initial implementation, 17 November 2026. Companion: [liblanis plan](../liblanis/OFFLINE_CACHE_MIGRATION.md).

## Offline app integration

Implemented session-independent offline route contexts, catalog-based module
availability, exact child-plan availability, local expiry checks, and local-only
image lookup. Offline navigation does not activate an account or change the
authentication state. Parent timetable tabs work in authenticated and offline routes, load the first
child automatically, and fetch other plans only when selected. Existing timetable and substitution views accept explicit data
sources and account settings. Cache settings count and clear SQLite snapshots as
well as downloaded files. Offline substitutions apply saved filters; changing
filters through the normal online filter screen remains disabled in offline mode.

The app now uses an explicit development path dependency on `../liblanis`.
Check out the two repositories side by side and run `flutter pub get`. Before
shipping, release the new library and replace that path with its hosted version;
published 0.1.5 lacks the new APIs. No package has been published by this change.

Validation: the full app suite passes 221 tests, including session-free
offline startup navigation, exact child availability, expiry, and local-only
notice images and fullscreen overlays. Static analysis has no errors or warnings;
existing informational lints remain.

The original phases below remain the design reference. Other applet homes and
detail reads can adopt the generated contracts in later increments.

## Baseline

This plan targets app commit `d03b5d47` on `main`. The app currently depends on
published liblanis 0.1.5. The library development branch contains parent Lessons
support in `03b45be` and parent timetable support in `6e7f93a`.

The current app offers cached applet homes from its startup error sheet through
`OfflineAvailableAppletsSection`. Timetable and substitutions are the enabled
offline modules. `CombinedAppletBuilder<T>` renders `FetcherResponse<T>` and
shows an offline banner with a fetch timestamp.

The database is already in persistent application-support storage. Downloaded
files use a separate temporary directory. The cache settings page currently
counts and clears downloaded files for the selected account, not structured
SQLite snapshots. The focused offline and error-view audit passed 17 tests.

## Preserve the current authentication flow

Keep `AuthController`, the startup error sheet, and explicit offline entry
points. Do not navigate to the normal authenticated home because cached data
exists. Do not introduce an authenticated state based on a cache hit or a
reachable server.

Offline module navigation remains a distinct route context. Every read within
that context uses `cacheOnly`, including later child-plan and course-detail
reads. This remains true if connectivity returns. The user explicitly retries
login through the existing startup flow before normal authenticated navigation
resumes.

A prepared local account or parser context is not proof of authentication.
Offline account selection must not make HTTP requests, including deauthentication
of a previous account. Add an explicit local-only selection path in the library
if the existing `ActiveAccount.select()` cannot meet that requirement. Keep
account-scoped providers isolated while avoiding network activity.

Provide an offline cache context containing the selected account metadata,
cache service, settings, and clock. It must have no dependency on
`sessionProvider`, `connectionCheckerProvider`, or network parser providers.
Use detached request factories with `readCacheFor()` to obtain typed results.
Keep normal online providers unchanged behind their authenticated entry points.

Existing timetable widgets watch `sessionProvider`, so changing account
selection alone is insufficient. Extract their data presentation from their
online loading wrapper, and add an offline wrapper that reads only the cache
context. Reuse the presenter and settings behavior without building the online
provider chain. Test the complete offline widget tree, not just mocked auth.

Suppress legacy `fetchData()` connectivity preflight, blanket authentication
retry, and auto-refresh timers before they can execute in an offline route.
Local expiry timers are allowed. A cache miss or expired entry leads to an
unavailable state and an explicit login retry action, never automatic login.

## Use the generic availability check

The library generates a typed cache request for every annotated function. The
app uses those descriptors rather than constructing JSON, method names, hashes,
or database keys itself.

```dart
final homeAvailable = await cache.isCacheAvailableFor(
	accountId: account.localId,
	request: TimetableParentParserCacheRequests.getHome(),
);

final childPlanAvailable = await cache.isCacheAvailableFor(
	accountId: account.localId,
	request: TimetableParentParserCacheRequests.getTimetable(reference),
);
```

These are examples of the same generic function. The check must not initialize
a parser, contact the connection checker, authenticate, or switch the active
account. It verifies that the exact operation and parameters have a usable
entry for the specified account. `readCacheFor()` uses the same descriptor to
read its value without constructing the corresponding network parser.

For a diagnostic or timestamp display, use `inspectCacheFor()` with the same
request. Only `available` enables offline navigation. Missing, expired,
incompatible, and corrupt data cannot be opened. A later cache read must still
handle expiry or eviction after an earlier successful check.

Home and detail checks are independent. A home response that includes a parsed
plan does not automatically create a cache entry for a separate detail method.
The UI follows the cached home's result variant rather than inventing another
function call.

## Module discovery

Replace raw `listAppletOfflineData()` iteration in
`lib/widgets/offline_available_applets_section.dart` with a module catalog and
availability checks:

1. Enumerate stored accounts without logging in.
2. Resolve applets supported by the app's UI and the persisted account type.
3. Obtain each applet's generated home request from the library module manifest.
4. Call `isCacheAvailableFor()` for that account and home request.
5. Show one tile per usable home, preserving existing labels and multi-account
   subtitles. Never present detail-operation rows as separate applets.
6. On selection, enter the explicit offline context and read that home with
   `cacheOnly`.

Use the app's existing module definitions to resolve labels, icons, and widgets.
Use the library manifest only for cache descriptors and ownership metadata.
Ignore unknown operation identifiers and unsupported UI account types safely.
Do not map an arbitrary cache identifier to a list index that can become `-1`.
Do not contact the portal to discover account type or applet permissions during
this listing.

Only home availability controls the module tile. A valid detail entry does not
make an expired or absent home available. This matches the requirement that a
module's home page must be ready for offline view.

## Cached timetables

Keep the parent timetable sealed result:

| Cached home result | Offline behavior |
| --- | --- |
| `ParentTimetableLoaded` | Show its `timetable` directly with its pupil ID. Do not issue another detail request. |
| `ParentTimetableSelection` | Show child references. Check each detail operation with its exact parameters. Enable only usable cached plans. |

A child row may be visible while its plan is not available offline. Display that
state explicitly rather than interpreting it as an empty timetable. A missing
or expired plan never triggers a network request from an offline route.

When online and authenticated, a successful annotated detail call stores that
function's result. Its availability can then be checked using the same generated
request and parameters. No timetable-specific cache lookup or payload alias is
needed in the app.

Add the parent timetable view, account support, and routes when updating the
library dependency. The existing student timetable continues to use its own
home descriptor and `TimeTable` rendering. Do not pass a parent selection or
loaded wrapper to a widget expecting a student `TimeTable`.

## Result metadata and expiry

Generated reads return `MaybeCacheResult<T>` on both network and cache success:

| Field | Meaning |
| --- | --- |
| `data` | The decoded domain result |
| `cacheStatus` | Whether this call returned network data or a cache hit |
| `fetchedAt` | Original successful network-fetch timestamp |
| `responseAt` | Timestamp of the current result delivery |
| `expiresAt` | Effective deadline, including any earlier nested dependency expiry |

Map `data` and `fetchedAt` into the existing shared applet presentation through
a compatibility adapter. Never label a cached value fresh because it was read
again. Never use `cacheStatus` to change `AuthController` authentication state.

If a fresh outer read consumes cached inner data, display the outer result as
cached. Preserve the oldest contributing `fetchedAt` and the earliest allowed
`expiresAt`. `responseAt` still records the current delivery. The single-child
redirect followed by an inner cached timetable is one example. Do not reset its
age when storing or presenting the enclosing home result.

A successful nullable network result can have `data: null`, but is not cached.
It represents the server's domain response, not an offline cache miss. Replace
any previous entry for that exact request so the old value does not become an
offline fallback after a successful null. Empty non-null lists remain cacheable.
Do not treat a null result as an available offline resource.

Refresh at the applet interval, but keep saved data usable offline for seven days.
This follows the user's updated retention decision after foreground outage testing.
Explicit shorter per-method limits may still apply. Timetables therefore refresh
hourly and substitutions every ten minutes without becoming unusable at those
intervals. The offline banner keeps the original fetch time visible.

An open offline screen should not continue presenting an expired snapshot as
currently available. Recheck validity when opening a resource, returning to its
route, or resuming the app, and schedule expiry handling for a displayed entry.
At expiry, explain that no valid offline copy remains and offer the existing
login retry path. Do not refresh through the network from an offline context.

## Filters, clearing, and deferred invalidation

Read unfiltered substitutions through the cached operation and apply current
account filters afterward. Use a projection or a copy. Never destructively
filter the shared cached object. Changing filters should immediately change
visible data without requiring another fetch or creating filter-specific cache
entries.

After clearing structured cache, update availability displays immediately.
An in-flight request started before the clear may return to its original online
caller, but must not persist into the cleared scope. The library uses persistent
clear generations for this guarantee, including across the background isolate.
Do not restore an old cache from widget state or allow a later response handler
to bypass that generation check.

Automatic invalidation after successful mutations is deferred. Existing online
UI updates can remain, but this migration does not guarantee that an offline
snapshot immediately reflects a homework change or sent message. A successful
read refresh, expiry, or explicit clearing governs those entries until the
invalidation follow-up is implemented.

## Implementation sequence

1. Release the library cache service, annotation generator, request descriptors,
   availability API, and legacy adapters described in the companion plan.
2. Update `pubspec.yaml` and `pubspec.lock`. Keep old applet result shapes working
   through the library compatibility adapter while updating call sites.
3. Add the session-free offline cache context, local-only account-selection
   path, and offline presenter wrappers. Keep the current startup UI and
   authentication phases. Carry the read context through nested routes rather
   than changing a global connectivity flag. Suppress legacy probes and auth
   retries before cache-only dispatch.
4. Migrate `OfflineAvailableAppletsSection` to generated home availability checks
   and module metadata. Keep unknown or unusable entries out of the list.
5. Pilot timetable home and child-plan reads. Add the parent result rendering
   described above. Validate both one-child and two-child flows.
6. Adapt `CombinedAppletBuilder` and detail loaders to the agreed result metadata.
   Preserve the timestamp banner and allow errors to remain errors. Keep
   existing data visible during an authenticated refresh only while it remains
   valid. Do not replace expired data with a successful empty result.
7. Move other reads to generated cached calls only as their models, routes, and
   offline UI are ready. Initial candidates include course detail reads. Move
   substitution filtering outside cached reads. Keep module homes and detail
   entries independently discoverable.
8. Update cache settings to expose structured-data usage and clearing, separately
   from downloads. Limit per-account actions to the selected account. Clearing
   cache data must not remove accounts, credentials, or authentication state.
   Verify that pre-clear in-flight requests cannot repopulate that scope.
9. Require `networkOnly` for background notification reads. Skip notifications
   on fetch failure rather than using fallback content as newly fetched data.
10. Remove the legacy applet-row discovery path after the library migration and
    app integration have both shipped and rollback has been tested.

Do not migrate write actions to automatic caching. In an offline context,
message sending, uploads, deletion, and homework changes remain unavailable.
Preserve drafts if already supported, but do not add offline write queues as
part of this change.

## Acceptance tests

Add app-level tests for the following cases:

- Cold start with network failure still shows the existing startup error flow.
  A cache hit never switches `AuthPhase` to authenticated.
- A reachable portal with failed login still permits explicit cache-only
  browsing. Opening or switching offline modules causes no HTTP or auth calls.
- One valid cached home produces one module tile. Expired, corrupt, incompatible,
  unknown, and unsupported entries produce no actionable tile.
- A detail entry alone does not create a home tile. A cached selection can list
  children even if only some of their detail calls have usable entries.
- A cached loaded home displays its plan without another detail call.
- Account, pupil, parameters, and schema versions remain isolated.
- Connectivity returning during offline browsing causes no implicit login,
  authenticated navigation, or network refresh.
- Explicit login retry uses the normal authentication flow and only successful
  authentication enables normal navigation.
- An entry expiring between inspection and opening produces an offline
  unavailable state. App resume and on-screen expiry respect the same limit.
- Cached timestamps preserve `fetchedAt` while `responseAt` changes. Nested
  cached inputs propagate their age and earliest expiry to enclosing results.
- A successful network null creates no available cache entry. Valid empty
  collections remain available.
- Changing substitution filters projects unfiltered cached data without network
  activity and does not mutate another view's cached data.
- The actual offline widget and provider graph constructs no session or checker.
  Legacy refresh callbacks and missing-cache error paths cause no auth calls.
- Concurrent background and foreground consumers retain their own read policy.
  A network-only notification task cannot inherit UI cache fallback.
- Clearing structured cache invalidates availability and leaves credentials and
  downloaded-file controls intact. A delayed request completion cannot
  repopulate a cleared scope. Removing an account removes its data only.
- Background notifications never use cache fallback as fresh content.

Retain the existing offline startup, account switching, course-error, and widget
lifecycle tests. Run the full Flutter suite and analyze both projects after the
library integration. This document schedules those changes and does not
implement them.
