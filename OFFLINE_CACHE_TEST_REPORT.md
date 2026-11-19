# Offline cache audit — 17 November 2026

Status: complete. Full suites: 281 library tests and 221 app tests passed. This report distinguishes device checks
from simulated failure tests; it does not claim that every backend failure was
induced against the live portal.

## Policy

Applet intervals control refresh cadence. Saved timetable and substitution results
remain usable offline for seven days from their original fetch date. An explicit
shorter operation limit still applies. Reading, displaying, or falling back does
not extend the deadline. Authentication and parsing failures remain errors.

The explicit offline startup flow stays separate from authenticated navigation.
The foreground network observer is mounted only by the authenticated shell and
is disposed when that shell closes. Interface availability never proves login or
server reachability, as noted in the [connectivity_plus documentation](https://pub.dev/packages/connectivity_plus/versions/7.0.0). A successful reachability probe triggers data refreshes,
not authentication.

## Fixes

| Failure point | Resulting behavior |
| --- | --- |
| Applet refresh deadline reached offline | Keep saved data until the retention deadline; retry at the normal cadence. |
| Android native client reports `DioExceptionType.unknown` | Inspect the structured underlying transport exception; use the matching cache entry. |
| HTTP 503 is accepted by the session client | Reject it as a transport failure before HTML parsing; cached reads can fall back. |
| No Cronet provider on the emulator | Use the Dart IO adapter instead of failing at startup. |
| Open a saved page while its network refresh is pending | Display the local result immediately, with its original date and offline badge. |
| Foreground connection disappears | Keep displayed resources and show the offline badge. |
| Connection returns | Refresh the visible resource; avoid repeating an already successful initial fetch. |
| Server stays unreachable while Wi-Fi remains connected | Probe again every 30 seconds while foregrounded; retain saved content between attempts. |
| Switch between parent timetable children | Keep separate keys, values, fetch dates, and visible-child state. |
| Hidden child tabs receive reconnect events | Stop their timers and defer their refreshes until selected. |
| Single-child home first shows an old preview | Replace it with the fresh home result without a duplicate detail request. |
| A request completes after a newer result or after disposal | Ignore its presentation result; do not start another HTTP read after a late cache lookup. |
| A cache entry is missing, corrupt, incompatible, or too old | Show an unavailable state for that resource; keep other child tabs usable. |
| A refresh fails on a loaded legacy applet | Keep its valid in-memory result without starting reauthentication for a transport failure. |
| Calendar wraps a transport failure as a parsing error | Preserve its structured transport cause so the legacy retention path can handle it. |
| Cache is cleared during an in-flight request | Persistent generation checks prevent the old request from repopulating it. |

The one-time SQLite migration updates the existing pilot-operation deadlines to
seven days from their original fetch dates. It preserves payloads and fetch dates,
leaves unrelated operations alone, and cannot restore entries already deleted by
previous cleanup.

## Manual emulator checks

Device: `emulator-5554`, Android SDK phone x86_64, debug build. Network changes use
Android Wi-Fi and mobile-data controls. Screenshots and UI hierarchy captures are
stored locally in `/tmp/lanis-offline-audit/`. App data was backed up before tests.
Only read operations and login/session requests were used against the portal;
no school records, teacher/admin settings, or account links were changed.

| Scenario | Evidence / result |
| --- | --- |
| Student substitutions: lose all interfaces while foregrounded | Existing empty-but-valid result remains visible with the offline badge. |
| Student timetable: open a saved plan after disconnecting | `student-timetable-open-offline.png`: timetable and original fetch date remain visible. |
| Student timetable: refresh offline | `student-timetable-refresh-offline.png`: no content loss. |
| Student timetable: background and resume offline | `student-timetable-resume-offline.png`: same plan and original date. |
| Student timetable: restore connectivity | `student-restored-online.png`: fresh data replaces the fallback and the badge clears. |
| Parent timetable: disconnect on the second child | `parent-child-two-offline.png`: selected child, tabs, and plan remain visible. |
| Parent timetable: refresh offline | `parent-child-two-offline-refresh.png`: same content and fetch date. |
| Parent timetable: switch to the other saved child | `parent-child-one-offline.png`: saved plan remains usable. |
| Parent timetable: switch back, background, resume offline | `parent-child-two-resume-offline.png`: child selection is retained. |
| Parent timetable: restore connectivity | `parent-restored-online.png`: cached content is replaced and the offline badge clears. |
| Cold start without a network | `cold-start-offline.png`: startup error sheet lists usable saved modules rather than entering authenticated navigation. |
| Open both children from cold offline startup | `cold-parent-first-offline.png`, `cold-parent-second-offline.png`: both saved plans open outside the authenticated shell. |
| Restore connectivity during explicit offline browsing | `explicit-offline-after-network-return.png`: the route remains offline and retains the original fetch date. |
| Five-day-old cache | `five-day-parent-first.png`, `five-day-parent-second.png`: both plans remain usable with the aged fetch date and corresponding cached week. |
| Corrupt cache for only the second child | `corrupt-child-two-unavailable.png`, `corrupt-switch-back-to-saved-child.png`: the invalid plan is unavailable; the other tab remains usable. |
| Missing cache for only the second child | `missing-child-two-unavailable.png`: an honest unavailable state appears without removing the tabs or the other plan. |
| Eight-day-old parent cache | `eight-day-parent-cache-unavailable.png`: the parent module is not offered; the other account's valid cached modules remain available. |
| Reach the seven-day deadline while a plan is open | `seven-day-boundary-before.png`, `seven-day-boundary-after.png`: the plan is initially visible, then becomes unavailable at the deadline without a crash. |
| App traffic blocked while Wi-Fi remains available | `parent-refresh-network-pending.png`, `parent-live-https-failure-fallback.png`: all 50 timetable cells remain visible during the pending request and the cached fallback. |
| Remove the app-only traffic block | `parent-after-app-network-recovery.png`: automatic refresh clears the offline badge without an interface change or a manual login. |

The app-only traffic block used temporary IPv4 and IPv6 owner rules for the debug
app UID. Packet counters confirmed blocked traffic. Both rules were removed,
ADB was returned to non-root mode, emulator latency was reset, and Wi-Fi/mobile
data were enabled afterward. The pre-test SQLite backup was restored after the
age/corruption fixtures; subsequent online reads refreshed it normally. The
emulator is left on the parent's online timetable.

The final debug APK was built for `android-x64` and installed on the emulator.
Library analysis reports no issues. App analysis reports no errors or warnings;
83 pre-existing informational lints remain. No implementation changes were committed.

Key screenshots: [foreground outage](/tmp/lanis-offline-audit/parent-live-https-failure-fallback.png),
[five-day-old saved plan](/tmp/lanis-offline-audit/five-day-parent-second.png),
[missing child](/tmp/lanis-offline-audit/missing-child-two-unavailable.png),
[recovered online view](/tmp/lanis-offline-audit/final-restored-parent-online.png).

## Automated checks

The app tests cover foreground loss, cached and uncached child switching,
background/resume, recovery, cache-only provider graphs, local images and fullscreen
overlays, hard retention boundaries, saved previews during pending refreshes,
refresh ordering, disposal, and preservation of authentication/parsing errors.

The library tests cover canonical keys and account isolation, native transport
causes, transient gateway failures, strict authentication/parser failures, nested
provenance, seven-day retention independent from refresh cadence, one-time deadline
migration, original timestamps, JSON compatibility, empty/null results, selective
clearing, and in-flight clear races across separate SQLite connections.

## Boundaries

Persistent generic cache coverage remains student/parent timetables, individual
parent plans, and unfiltered substitutions. Already-loaded legacy applet homes can
survive a foreground outage in memory; this does not create durable offline caches
for all other modules or their detail screens. Mutation invalidation remains deferred.

The emulator has no enabled Cronet provider, so its live HTTP checks exercise the
IO fallback. Native client exception handling is covered by typed adapter regression
tests. Long retention intervals are tested with synthetic cache timestamps and exact
clock-boundary tests, rather than by waiting seven days. Deliberately invalid live
credentials were not used; authentication failure behavior is tested with fakes.

## Banner placement follow-up (2026-11-17)

The shared offline banner now has a screen-level host for views whose data source is nested below a fixed app bar. Parent timetable, messages, calendar, student lessons, teacher lessons, and timetable settings use this host. Standalone data-source screens keep the same banner layout. The host uses only visible sources, preserving each child’s fetch timestamp when switching timetable tabs.

Installed the updated x64 debug APK on `emulator-5554`. Loaded parent timetable, messages, and lessons online, disconnected Wi-Fi and mobile data, then inspected screenshots and accessibility bounds. Both timetable children, parent messages, and parent lessons showed exactly one banner above the app-bar title. Repeated the checks with the student account for timetable, calendar, messages, lessons, and substitutions. All nine screenshots place the banner text at y=79–131 and the app-bar title at y=184–257. Screenshot/XML files are `/tmp/lanis-offline-audit/banner-*-offline.*`. Teacher lessons and timetable settings received the shared layout fix but were not manually exercised in this follow-up.

All 221 app tests pass, including new geometry assertions during parent timetable disconnection and child switching. Analyzer reports the existing 83 informational lints, with no warnings or errors. Logs: `/tmp/lanis-banner-full-tests.log`, `/tmp/lanis-banner-analyze-final.log`, and `/tmp/lanis-banner-build.log`.

## Global shell banner (2026-11-18)

This replaces the per-screen banner hosts described above. `HomePage` now mounts one `GlobalOfflineShell` above all branch navigators and app bars. It reads the existing global connection checker and network-interface status. Applet parsers, cached responses, loading/errors, and tab disposal no longer control banner visibility or report timestamps to the shell. The global label is simply “Offline”; resource fetch timestamps remain in cache metadata rather than being presented as a single global fetch time. The icon is Flutter’s `Icons.cloud_off_outlined`. Explicit offline startup uses the same layout with a fixed offline flag and no session/checker dependency.

Removed all per-applet banner wrappers and the asynchronous registration callbacks. Kept navigator semantics before the banner in widget traversal while positioning the banner above the content, so nested route semantics do not hide the global status from accessibility tools.

Regression tests cover the same banner element and fixed geometry on the first frame of applet changes, loading, error, and detail states; immediate interface loss; reconnect; accessible status above a nested navigator; and the cloud-off icon. All 224 app tests pass. Analyzer reports the existing 83 informational lints, with no warnings/errors. Logs: `/tmp/lanis-global-banner-final-full-tests.log`, `/tmp/lanis-global-banner-final-analyze.log`, `/tmp/lanis-global-banner-final-build.log`.

Live emulator checks used the existing parent test account, re-added through normal login because the emulator started at onboarding. Loaded timetable and messages, disconnected Wi-Fi and mobile data, then switched ten times between timetable, messages, and initially uncached Lessons. The banner remained visible above both saved content and the Lessons network-error screen. A 12-second recording (`/tmp/lanis-offline-audit/global-banner-switches.mp4`) captured 61 frames; the banner region’s largest mean RGB difference from its initial frame was 0.311/255, consistent with video encoding variation and no disappearance or movement. Reconnecting removed the banner and recovered Lessons.

Installed the final build with the cloud-off icon and accessibility ordering fix. `/tmp/lanis-offline-audit/global-banner-cloud-off-final.png` confirms the icon above the parent timetable app bar; its XML now exposes the “Offline” label as well. Restored Wi-Fi and mobile data and confirmed the banner disappears on reconnection. The emulator is left online on the parent timetable.

## Parent app bars during offline errors (2026-11-19)

Parent Lessons supplied its title and drawer button only after the overview loaded. Its loading/error scaffold had no app bar. Added the same titled header to session loading and parser loading/error states. Parent timetable overview loading, overview errors, and empty selections now use a shared titled header with the drawer callback. Successful child tabs keep their existing controls. Attendance loading/error screens reuse the successful attendance header, including the child name when already known.

The broader parent-capable screen audit found the same missing loading header in substitutions while waiting for a session, plus message recipients loading/errors and prefilled message composition loading. These now retain their corresponding titles. Calendar, messages overview, course details, and data storage already keep their app bars outside the loading/error body.

Added regression coverage for parent Lessons offline errors, working drawer actions and successful retry; Lessons loading headers; attendance error headers; parent timetable overview loading/error/retry and empty selection; and message recipients loading/offline errors. All 229 app tests pass. Analyzer has the existing 83 informational lints and no warnings/errors. Logs: `/tmp/lanis-parent-headers-final-tests.log`, `/tmp/lanis-parent-headers-final-analyze.log`, `/tmp/lanis-parent-headers-final-build.log`.

Installed the updated x64 debug build on the fresh emulator and signed into the existing parent test account through the normal UI. Disconnected Wi-Fi and mobile data before opening Lessons and Messages. Both showed the offline error, a titled app bar, and the global cloud-off banner above it. Verified the Lessons menu opens the drawer. The saved first-child timetable retained its header and tabs; the uncached second child showed a local cache miss while retaining the same header and tabs. Opened the attendance deep link offline and verified its titled app bar above the error. Screenshots/XML: `/tmp/lanis-parent-offline-headers/parent-lessons-offline-error.*`, `parent-lessons-offline-drawer.*`, `parent-messages-offline.*`, `parent-timetable-first-cached.*`, `parent-timetable-second-cache-miss.*`, and `parent-attendance-offline.*`.

Restored connectivity and verified Lessons recovered. The previously hidden second-child cache-miss view required its existing “Try again” action after reconnecting; this follow-up changes headers, not hidden-page recovery behavior. Restored the emulator online on the parent timetable. No teacher/admin data was modified.

## Cached child preparation and missing-data state (2026-11-19)

Explicit offline parent timetable browsing now loads the child cache entries once before presenting the tabs. Their decoded results initialize each cached child view directly; missing entries are identified from the same lookup instead of separate availability queries. Additional online child requests remain lazy. Prepared data is available synchronously to the first build, and settings initialization no longer waits for an extra frame. A cache-only data source returns after a successful preview read and does not repeat a failed local lookup.

Missing offline cache entries use an accessible cloud-off icon without retry, stack trace, or diagnostic text. Uncached child tabs use `Icons.error_outline`, replacing the previous checkmark-style offline-pin icon. App bars and the global offline banner remain visible.

All 233 app tests pass, including both cached and uncached second-child fixtures, no loading spinner on the first switch frame with prepared data, no retry/stack-trace controls for missing entries, a single cache-only lookup, and synchronous availability of prepared results. Analyzer reports the existing 83 informational lints with no warnings/errors. Logs: `/tmp/lanis-offline-preload-full-tests.log`, `/tmp/lanis-offline-preload-final-analyze.log`, `/tmp/lanis-offline-preload-build.log`.

Installed and manually checked the updated x64 debug build. Opened the explicit offline parent timetable and switched between both cached children. Then temporarily removed only the second child’s local cache entry, reopened the offline timetable, and verified the error-outline badge and cloud-only page. Its accessibility dump contains “Not available offline” but neither “Try again” nor “Stack Trace”. Restored the exact original cache row and re-enabled Wi-Fi and mobile data. Screenshots: `/tmp/lanis-parent-offline-headers/preload-first-ready.png`, `preload-second-ready.png`, `preload-missing-tab-marker.png`, and `preload-missing-child-cloud-only.png`.

## Shared timetable customization (2026-11-19)

Replaced the student-specific editor with a shared timetable customization view and modifications editor. Students keep their existing account-level settings and JSON format. Parents reuse the existing parent timetable loader and child tabs, with the same editor consuming the selected child’s timetable. Both the editor and timetable renderer use settings namespaced by pupil ID. This also isolates hidden lessons and lesson colors between siblings. Existing unscoped parent rows are left untouched and are not assigned automatically to a child.

The editor has one scrollable list: individual custom lesson cards ordered Monday–Sunday and then by start time, followed by hidden lessons only when present. The add/edit dialog selects a weekday explicitly; editing can move an entry between days. Restoring the final hidden lesson removes the section. The normal timetable reloads settings on becoming visible, so returning from editing shows changes immediately. Updated the old restart-app hint in German and English to explain that these changes stay in the app.

All 241 app tests and 282 library tests pass. New coverage checks shared student/parent UI, unchanged student storage, multi-child and single-loaded-child parent parsing, child isolation for custom and hidden lessons, ordering, omission of empty hidden sections, edit/move/delete, typed settings namespaces, and updating an existing timetable after returning from the editor. App analyzer has 82 informational lints and no warnings/errors; library analyzer is clean. Logs: `/tmp/lanis-custom-final-all-tests.log`, `/tmp/lanis-custom-final-feature-tests.log`, `/tmp/lanis-custom-parent-final-tests.log`, `/tmp/liblanis-custom-all-tests.log`, `/tmp/lanis-custom-final-analyze.log`, `/tmp/liblanis-custom-analyze.log`, `/tmp/lanis-custom-final-build.log`.

On the Android emulator, added a temporary local “Test AG” entry for the first child. Verified it in that child’s unified editor and timetable and confirmed it was absent in both views for the second child. Hid a first-child school lesson, verified the hidden section appeared beneath the custom entry, restored the lesson and confirmed the section disappeared, then deleted the custom entry. Backed up and restored the exact original child-settings rows; the baseline had no child-specific rows. No portal data was modified. Screenshots/XML are `/tmp/lanis-parent-offline-headers/custom-*.png` and `.xml`; the settings backup is `/tmp/lanis-custom-editor-audit/settings.json`. Installed the final debug build with the updated hint text.

## Settings styling follow-up (2026-11-19)

Restored the standard `SettingsPage` and settings color lifecycle around the shared timetable customization editor. The large settings heading and standard back behavior own the page chrome; parent child tabs remain below that header without a duplicate toolbar. Nested editor surfaces and cards use the existing light/dark settings colors.

All 21 relevant customization, parent timetable, and offline-flow tests pass. Analyzer reports 82 informational lints and no warnings/errors. Installed the updated x64 debug build and visually verified the parent editor in both light and dark modes; restored the emulator’s original light-mode setting. No timetable settings or portal data were changed. Screenshots: `/tmp/lanis-parent-offline-headers/settings-style-restored-light.png` and `settings-style-restored-dark.png`. Logs: `/tmp/lanis-settings-style-final-tests.log`, `/tmp/lanis-settings-style-analyze.log`, `/tmp/lanis-settings-style-build.log`.
