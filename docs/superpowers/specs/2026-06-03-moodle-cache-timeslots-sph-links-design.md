# Design: Moodle-Cookie-Cache, Mehrere Benachrichtigungs-Zeiträume, SPH-interne Links

**Issues:** #431, #343, #202
**Date:** 2026-06-03

---

## #431 — Moodle-Cookie-Cache

### Ziel
`MoodleWebView` macht aktuell bei jedem Öffnen 6 HTTP-Requests (vollständiger SSO-Flow). Gecachte Cookies sollen den Flow auf 0 Requests reduzieren, mit automatischem stillem Fallback.

### Datenmodell
Cookies werden im Account-Preferences-KV (`sph.prefs.kv`) als JSON gespeichert:
- Key: `moodle-cached-cookies`
- Value: JSON-String mit `[{name, value, domain, path, url}, ...]` für die drei Cookies `mo-prod01`, `MOODLEID1_`, `MoodleSession`

### Ablauf
1. **App öffnet MoodleWebView:**
   - Lade gecachte Cookies aus `sph.prefs.kv.get('moodle-cached-cookies')`.
   - Wenn vorhanden: Cookies in WebView-CookieManager setzen, direkt `loadUrl` aufrufen, `isLoggedIn = true`. Kein SSO-Flow.
   - Wenn nicht vorhanden: Voller SSO-Flow wie bisher.
2. **Nach erfolgreichem SSO-Flow:** Drei Cookies (`mo-prod01`, `MOODLEID1_`, `MoodleSession`) als JSON in KV speichern.
3. **Fallback bei abgelaufenen Cookies:** `onLoadStop` prüft die aktuelle URL. Wenn sie auf eine Moodle-Login-Seite zeigt (URL enthält `/login/index.php` und kein `wantsurl`-Parameter), werden gecachte Cookies gelöscht und der volle SSO-Flow gestartet, anschließend wird die Seite neu geladen.

### Betroffene Dateien
- `lib/view/moodle.dart`

---

## #343 — Mehrere Benachrichtigungs-Zeiträume

### Ziel
Nutzer können mehrere Start/Ende-Zeiträume für den Background-Service konfigurieren (z.B. 7–12 Uhr und 14–18 Uhr). Der Service ist aktiv, wenn die aktuelle Uhrzeit in **irgendeinem** der Zeiträume liegt.

### Datenmodell
Neuer KV-Key (global, `accountDatabase.kv`):
- Key: `notifications-time-periods`
- Typ: `List<List<int>>` — jeder Eintrag: `[startHour, startMinute, endHour, endMinute]`
- Default (Android): `[[6, 30, 15, 0]]`
- Default (iOS): `[[5, 30, 16, 30]]`

Die alten Keys `notifications-start-time` und `notifications-end-time` werden bei der Migration übernommen und danach nicht mehr genutzt.

### Migration
In `notifications.dart` beim `initVars()`-Aufruf: Wenn `notifications-time-periods` noch nicht existiert (null), werden `notifications-start-time` und `notifications-end-time` aus dem alten Format gelesen und als erster Zeitraum ins neue Format geschrieben.

### UI (`notifications.dart`)
Der bisherige `RangeSliderTile` wird durch folgendes ersetzt:
- Eine Liste von `ListTile`s, je ein Eintrag pro Zeitraum:
  - Linkes Icon: `Icons.schedule_outlined`
  - Titel: `"HH:MM – HH:MM"` (formatiert)
  - Trailing: Bearbeiten-Icon (`Icons.edit`) + Löschen-Icon (`Icons.delete`) — Löschen deaktiviert wenn nur ein Zeitraum vorhanden.
- Unter der Liste: `TextButton.icon(Icons.add, 'Zeitraum hinzufügen')`.
- Bearbeiten/Hinzufügen öffnet einen Dialog mit zwei `TimePickerButton`-Widgets (Start, dann Ende via `showTimePicker`).

### Logik (`background_service.dart`)
`isAllowedTime()` liest `notifications-time-periods` statt der alten Keys. Gibt `true` zurück wenn die aktuelle `TimeOfDay` in mindestens einem Zeitraum liegt.

```
bool isInPeriod(TimeOfDay now, List<int> period):
  nowMin = now.hour * 60 + now.minute
  startMin = period[0] * 60 + period[1]
  endMin = period[2] * 60 + period[3]
  return nowMin >= startMin && nowMin <= endMin
```

### Betroffene Dateien
- `lib/core/database/account_database/kv_defaults.dart`
- `lib/background_service.dart`
- `lib/view/settings/subsettings/notifications.dart`

---

## #202 — SPH-interne Links in der App öffnen

### Ziel
Links auf `start.schulportal.hessen.de` in SPH-Nachrichten/Texten sollen direkt zum entsprechenden App-Applet navigieren, statt den externen Browser zu öffnen.

### Logik
Neue Top-Level-Funktion `bool navigateToSphUrl(BuildContext context, Uri uri)` in `lib/widgets/format_text.dart`:

1. Prüfe ob `uri.host == 'start.schulportal.hessen.de'`.
2. Extrahiere den PHP-Filename aus dem Pfad (z.B. `kalender.php` aus `/kalender.php`).
3. Suche in `AppDefinitions.applets` nach einem Applet mit `appletPhpUrl == phpFilename`.
4. Prüfe `sph!.session.doesSupportFeature(applet)`.
5. Wenn Match und unterstützt: `Navigator.of(context).push(MaterialPageRoute(...))` mit `applet.bodyBuilder!(context, sph!.session.accountType, () {})`. Gibt `true` zurück.
6. Sonst: Gibt `false` zurück → Aufrufer nutzt `openUrlModal` wie bisher.

### Integration in `format_text.dart`
Beim URL-Tap (Zeile ~346) wird vor `openUrlModal` geprüft:
```dart
if (!navigateToSphUrl(context, uri)) {
  openUrlModal(context, uri);
}
```

### Betroffene Dateien
- `lib/widgets/format_text.dart`
