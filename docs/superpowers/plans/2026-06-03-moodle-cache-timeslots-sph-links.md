# Moodle Cache / Notification Timeslots / SPH Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement three independent improvements: cached Moodle SSO cookies (#431), multiple configurable notification time windows (#343), and in-app navigation for SPH links (#202).

**Architecture:** All three features are self-contained. #431 modifies only `moodle.dart` — it stores/restores three cookies in the account KV store and adds a login-page detection hook in `onLoadStop`. #343 replaces the single `RangeSliderTile` with a multi-period list in `notifications.dart`, updates `kv_defaults.dart` with the new key, migrates old keys on first read, and rewrites `isTaskWithinConstraints` in `background_service.dart`. #202 adds one helper function in `format_text.dart` and calls it before `openUrlModal`.

**Tech Stack:** Flutter/Dart, `flutter_inappwebview` CookieManager, drift KV store (`sph.prefs.kv`), `showTimePicker`, `AppDefinitions.applets`.

---

## File Map

| File | Change |
|------|--------|
| `lib/view/moodle.dart` | Cache/restore 3 cookies in KV; detect login page in `onLoadStop`; re-auth silently |
| `lib/core/database/account_database/kv_defaults.dart` | Add `notifications-time-periods` default |
| `lib/background_service.dart` | Rewrite `isTaskWithinConstraints` to use new key |
| `lib/view/settings/subsettings/notifications.dart` | Replace `RangeSliderTile` with multi-period list UI; add migration |
| `lib/widgets/format_text.dart` | Add `navigateToSphUrl`; call it before `openUrlModal` |

---

## Task 1: Moodle cookie cache — store after successful SSO (#431)

**Files:**
- Modify: `lib/view/moodle.dart`

The cookies are obtained at lines 161–174. After `addWebViewCookies(...)` at line 178, save them to `sph!.prefs.kv`.

- [ ] **Add `_saveMoodleCookies` helper method** to `_MoodleWebViewState` (place above `getCookies`):

```dart
Future<void> _saveMoodleCookies(
  dio_core.Cookie moProd01,
  dio_core.Cookie moodleId1,
  dio_core.Cookie moodleSession,
  String moProd01Url,
  String moodleUrl,
) async {
  final data = [
    {
      'name': moProd01.name,
      'value': moProd01.value,
      'domain': moProd01.domain ?? '',
      'path': moProd01.path ?? '/',
      'url': moProd01Url,
    },
    {
      'name': moodleId1.name,
      'value': moodleId1.value,
      'domain': moodleId1.domain ?? '',
      'path': moodleId1.path ?? '/',
      'url': moodleUrl,
    },
    {
      'name': moodleSession.name,
      'value': moodleSession.value,
      'domain': moodleSession.domain ?? '',
      'path': moodleSession.path ?? '/',
      'url': moodleUrl,
    },
  ];
  await sph!.prefs.kv.set('moodle-cached-cookies', data);
}
```

- [ ] **Call `_saveMoodleCookies` in `getCookies`** — after the existing `addWebViewCookies(...)` call and before `webViewController!.loadUrl(...)`:

```dart
await _saveMoodleCookies(
  moProd01Cookie,
  moodleId1Cookie,
  moodleSessionCookie,
  location3,
  location4,
);
```

- [ ] **Verify analyzer**

```bash
flutter analyze lib/view/moodle.dart
```
Expected: `No issues found!`

---

## Task 2: Moodle cookie cache — restore on open, fallback on login page (#431)

**Files:**
- Modify: `lib/view/moodle.dart`

- [ ] **Add `_loadCachedMoodleCookies` helper** to `_MoodleWebViewState`:

```dart
Future<bool> _loadCachedMoodleCookies() async {
  final cached = await sph!.prefs.kv.get('moodle-cached-cookies');
  if (cached == null) return false;
  try {
    final List<dynamic> cookies = cached as List<dynamic>;
    for (final c in cookies) {
      await cookieManager.setCookie(
        url: WebUri(c['url'] as String),
        name: c['name'] as String,
        value: c['value'] as String,
        domain: c['domain'] as String,
        path: c['path'] as String,
        isHttpOnly: true,
        isSecure: true,
      );
    }
    return true;
  } catch (_) {
    await sph!.prefs.kv.set('moodle-cached-cookies', null);
    return false;
  }
}
```

- [ ] **Modify `getCookies` to try cache first** — replace the opening of `getCookies` (the `setState` + `try` block) so it checks cache before doing the full SSO flow:

```dart
Future<void> getCookies({bool forceFull = false}) async {
  if (!(await connectionChecker.connected)) {
    setState(() {
      isLoginError = true;
      noInternetLogin = true;
    });
    return;
  }

  setState(() {
    isLoginError = false;
    noInternetLogin = false;
  });

  if (!forceFull) {
    final restored = await _loadCachedMoodleCookies();
    if (restored) {
      webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(
            "https://mo${sph!.account.schoolID}.schulportal.hessen.de",
          ),
        ),
      );
      setState(() {
        isLoggedIn = true;
      });
      return;
    }
  }

  // Full SSO flow continues unchanged below...
  try {
    // ... (existing SSO code unchanged)
```

> The existing `try { ... } catch (e) { ... }` block stays exactly as-is after this new early-return block.

- [ ] **Add login-page detection in `onLoadStop`** — replace the existing `onLoadStop` handler:

```dart
onLoadStop: (controller, url) async {
  pullToRefreshController!.endRefreshing();
  progressIndicator.value = 0;

  // Detect Moodle session expiry: login page without a wantsurl param.
  if (url != null) {
    final uri = Uri.tryParse(url.rawValue);
    if (uri != null &&
        uri.path.contains('/login/index.php') &&
        !uri.queryParameters.containsKey('wantsurl')) {
      // Session expired — clear cache and re-auth silently.
      await sph!.prefs.kv.set('moodle-cached-cookies', null);
      await cookieManager.deleteAllCookies();
      setState(() {
        isLoggedIn = false;
      });
      await getCookies(forceFull: true);
      return;
    }
  }

  setState(() {}); // error
},
```

- [ ] **Verify analyzer**

```bash
flutter analyze lib/view/moodle.dart
```
Expected: `No issues found!`

---

## Task 3: Add `notifications-time-periods` KV default (#343)

**Files:**
- Modify: `lib/core/database/account_database/kv_defaults.dart`

- [ ] **Add the new key** to `kvDefaults`:

```dart
import 'dart:io';

final Map<String, dynamic> kvDefaults = {
  "notifications-target-interval-minutes": 30,
  "notifications-allowed-days": [true, true, true, true, true, false, false],
  "notifications-start-time": Platform.isIOS ? [5, 30] : [6, 30],
  "notifications-end-time": Platform.isIOS ? [16, 30] : [15, 0],
  "notifications-time-periods": Platform.isIOS
      ? [[5, 30, 16, 30]]
      : [[6, 30, 15, 0]],
  "last-app-version": "0.0.0",
  "color": "standard",
  "theme": "system",
  "is-amoled": false,
};
```

- [ ] **Verify analyzer**

```bash
flutter analyze lib/core/database/account_database/kv_defaults.dart
```
Expected: `No issues found!`

---

## Task 4: Rewrite `isTaskWithinConstraints` to use new key (#343)

**Files:**
- Modify: `lib/background_service.dart`

The current `isTaskWithinConstraints` (lines 286–306) reads `notifications-start-time` and `notifications-end-time`. Replace it entirely:

- [ ] **Replace `isTaskWithinConstraints`**:

```dart
Future<bool> isTaskWithinConstraints(AccountDatabase accountDB) async {
  final globalSettings = await accountDB.kv.getMultiple([
    'notifications-allowed-days',
    'notifications-time-periods',
  ]);

  final int currentDayIndex = DateTime.now().weekday - 1;
  if (!(globalSettings['notifications-allowed-days'][currentDayIndex] as bool)) {
    return false;
  }

  final now = TimeOfDay.now();
  final int nowMinutes = now.hour * 60 + now.minute;

  final List<dynamic> periods = globalSettings['notifications-time-periods'];
  return periods.any((period) {
    final int start = (period[0] as int) * 60 + (period[1] as int);
    final int end = (period[2] as int) * 60 + (period[3] as int);
    return nowMinutes >= start && nowMinutes <= end;
  });
}
```

- [ ] **Verify analyzer**

```bash
flutter analyze lib/background_service.dart
```
Expected: `No issues found!`

---

## Task 5: Replace RangeSliderTile with multi-period UI in notifications.dart (#343)

**Files:**
- Modify: `lib/view/settings/subsettings/notifications.dart`

This is the largest task. The state class currently holds `startTime` and `endTime` as `TimeOfDay`. We replace these with a `List<List<int>>` representing the periods, add migration, and rebuild the relevant UI section.

### Step A — Update state fields

- [ ] **Replace** the two `TimeOfDay` fields and the `RangeSliderTile`-related state in `_NotificationSettingsState`:

Remove:
```dart
TimeOfDay startTime = TimeOfDay(
  hour: kvDefaults['notifications-start-time'][0],
  minute: kvDefaults['notifications-start-time'][1],
);
TimeOfDay endTime = TimeOfDay(
  hour: kvDefaults['notifications-end-time'][0],
  minute: kvDefaults['notifications-end-time'][1],
);
```

Add in their place:
```dart
List<List<int>> timePeriods = List<List<int>>.from(
  (kvDefaults['notifications-time-periods'] as List).map(
    (p) => List<int>.from(p as List),
  ),
);
```

### Step B — Update `getDatabaseKeys`

- [ ] **Replace** the keys list in `getDatabaseKeys`:

```dart
List<String> getDatabaseKeys() {
  List<String> result = ["notifications-allow"];

  for (final applet in AppDefinitions.applets.where(
    (a) => a.notificationTask != null,
  )) {
    if (sph!.session.doesSupportFeature(applet)) {
      result.add('notification-${applet.appletPhpUrl}');
      supportedApplets['notification-${applet.appletPhpUrl}'] = applet;
    }
  }

  return result;
}
```

(No change here — `getDatabaseKeys` is already correct. The time periods are loaded separately in `initVars`.)

### Step C — Update `initVars` with migration

- [ ] **Replace `initVars`** entirely:

```dart
void initVars() async {
  notificationPermissionStatus = await Permission.notification.status;

  final globalSettings = await accountDatabase.kv.getMultiple([
    'notifications-target-interval-minutes',
    'notifications-allowed-days',
    'notifications-time-periods',
    'notifications-start-time',
    'notifications-end-time',
  ]);

  // Migration: if new key missing, seed from old keys.
  List<List<int>> periods;
  final raw = globalSettings['notifications-time-periods'];
  if (raw == null) {
    final oldStart = globalSettings['notifications-start-time'] ??
        kvDefaults['notifications-start-time'];
    final oldEnd = globalSettings['notifications-end-time'] ??
        kvDefaults['notifications-end-time'];
    periods = [
      [oldStart[0] as int, oldStart[1] as int, oldEnd[0] as int, oldEnd[1] as int],
    ];
    await accountDatabase.kv.set('notifications-time-periods', periods);
  } else {
    periods = List<List<int>>.from(
      (raw as List).map((p) => List<int>.from(p as List)),
    );
  }

  setState(() {
    notificationPermissionStatus = notificationPermissionStatus;
    targetNotificationInterval =
        globalSettings['notifications-target-interval-minutes'].toDouble();
    enabledDays = globalSettings['notifications-allowed-days']
        .map<bool>((e) => e as bool)
        .toList();
    timePeriods = periods;
  });
}
```

### Step D — Add helper method `_formatPeriod` and `_editPeriod`

- [ ] **Add two helper methods** to `_NotificationSettingsState` (place before `build`):

```dart
String _formatPeriod(List<int> period) {
  final start = TimeOfDay(hour: period[0], minute: period[1]);
  final end = TimeOfDay(hour: period[2], minute: period[3]);
  return '${start.format(context)} – ${end.format(context)}';
}

Future<void> _editPeriod(int index) async {
  final existing = index < timePeriods.length ? timePeriods[index] : null;
  final initialStart = existing != null
      ? TimeOfDay(hour: existing[0], minute: existing[1])
      : TimeOfDay(hour: 6, minute: 30);
  final initialEnd = existing != null
      ? TimeOfDay(hour: existing[2], minute: existing[3])
      : TimeOfDay(hour: 15, minute: 0);

  final start = await showTimePicker(
    context: context,
    initialTime: initialStart,
    helpText: 'Startzeit',
  );
  if (start == null || !mounted) return;

  final end = await showTimePicker(
    context: context,
    initialTime: initialEnd,
    helpText: 'Endzeit',
  );
  if (end == null || !mounted) return;

  final newPeriod = [start.hour, start.minute, end.hour, end.minute];
  final updated = List<List<int>>.from(timePeriods);
  if (index < updated.length) {
    updated[index] = newPeriod;
  } else {
    updated.add(newPeriod);
  }

  setState(() => timePeriods = updated);
  await accountDatabase.kv.set('notifications-time-periods', updated);
}
```

### Step E — Replace the `RangeSliderTile` section in `build`

- [ ] **Find** the `RangeSliderTile` widget in the `build` return list. It starts with:
```dart
Padding(
  padding: const EdgeInsets.only(left: 16.0, top: 8.0),
  child: RangeSliderTile(
```
and ends after `onChangeEnd: (newValues) { ... },` closing `),` and `),`.

**Replace that entire `RangeSliderTile` Padding widget** with:

```dart
// Time periods list
...timePeriods.asMap().entries.map((entry) {
  final i = entry.key;
  final period = entry.value;
  return Padding(
    padding: const EdgeInsets.only(left: 16.0, right: 8.0, bottom: 4.0),
    child: Row(
      children: [
        Icon(
          Icons.schedule_outlined,
          color: activateBackgroundServices
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 24.0),
        Expanded(
          child: Text(
            _formatPeriod(period),
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: activateBackgroundServices
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: activateBackgroundServices
              ? () => _editPeriod(i)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: activateBackgroundServices && timePeriods.length > 1
              ? () async {
                  final updated = List<List<int>>.from(timePeriods)..removeAt(i);
                  setState(() => timePeriods = updated);
                  await accountDatabase.kv.set(
                    'notifications-time-periods',
                    updated,
                  );
                }
              : null,
        ),
      ],
    ),
  );
}),
Padding(
  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
  child: TextButton.icon(
    icon: const Icon(Icons.add),
    label: const Text('Zeitraum hinzufügen'),
    onPressed: activateBackgroundServices
        ? () => _editPeriod(timePeriods.length)
        : null,
  ),
),
```

- [ ] **Remove the unused import** `range_slider_tile.dart` if `RangeSliderTile` is no longer referenced anywhere in the file:

```bash
grep -n "RangeSliderTile\|range_slider_tile" lib/view/settings/subsettings/notifications.dart
```

If no occurrences: remove the import line `import '../../../utils/range_slider_tile.dart';`.

- [ ] **Verify analyzer**

```bash
flutter analyze lib/view/settings/subsettings/notifications.dart
```
Expected: `No issues found!`

---

## Task 6: Add `navigateToSphUrl` and wire into format_text.dart (#202)

**Files:**
- Modify: `lib/widgets/format_text.dart`

- [ ] **Add import** at the top of `format_text.dart` (after existing imports):

```dart
import '../applets/definitions.dart';
import '../core/sph/sph.dart';
```

- [ ] **Add `navigateToSphUrl` function** as a top-level function in `format_text.dart` (place before or after `openUrlModal` usage, near top of file):

```dart
/// Navigates in-app to the matching applet if [uri] is a known SPH URL.
/// Returns true if navigation was handled, false if the caller should fall back.
bool navigateToSphUrl(BuildContext context, Uri uri) {
  if (uri.host.toLowerCase() != 'start.schulportal.hessen.de') return false;

  // Extract the PHP filename (e.g. "kalender.php" from "/kalender.php")
  final phpFile = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  if (phpFile.isEmpty) return false;

  final applet = AppDefinitions.applets
      .where((a) => a.appletPhpUrl == phpFile)
      .firstOrNull;
  if (applet == null) return false;
  if (!sph!.session.doesSupportFeature(applet)) return false;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (ctx) =>
          applet.bodyBuilder!(ctx, sph!.session.accountType, () {}),
    ),
  );
  return true;
}
```

- [ ] **Update the `onTap` handler** in the `"a"` tag builder (currently at line ~358):

Find:
```dart
onTap: () async {
  await openUrlModal(context, Uri.parse(attributes["href"]!));
},
```

Replace with:
```dart
onTap: () async {
  final uri = Uri.tryParse(attributes["href"]!);
  if (uri == null) return;
  if (!navigateToSphUrl(context, uri)) {
    await openUrlModal(context, uri);
  }
},
```

- [ ] **Verify analyzer**

```bash
flutter analyze lib/widgets/format_text.dart
```
Expected: `No issues found!`

---

## Task 7: Full analyze

- [ ] **Run full analyze on all changed files**

```bash
flutter analyze lib/view/moodle.dart lib/core/database/account_database/kv_defaults.dart lib/background_service.dart lib/view/settings/subsettings/notifications.dart lib/widgets/format_text.dart
```
Expected: `No issues found!`
