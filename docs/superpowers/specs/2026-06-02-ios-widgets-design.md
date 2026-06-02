# iOS Widgets & Live Activities — Design Spec

**Date:** 2026-06-02  
**App:** lanis (Bundle ID: `io.github.alessioc42.sph`)  
**iOS Minimum:** iOS 13 (Widgets: iOS 14+, Lock Screen: iOS 16+, Live Activities: iOS 16.2+)

---

## Ziel

Native iOS Home-Screen-Widgets und Live Activities für die lanis-App, die Schülern auf einen Blick die wichtigsten Schulinformationen zeigen — ohne die App öffnen zu müssen. Design orientiert sich am bestehenden Material-You-Stil der App (Dynamic Color, SF Pro als iOS-Pendant).

---

## Architektur

```
Flutter App
  └── WidgetDataService (lib/core/widget_data_service.dart)
        ├── schreibt JSON → App Group UserDefaults
        │     (group: io.github.alessioc42.sph.widgets)
        └── MethodChannel('io.github.alessioc42.sph/widgets')
              └── WidgetChannel.swift
                    ├── writeData(key, json) → UserDefaults(suiteName:)
                    ├── reloadWidgets() → WidgetCenter.shared.reloadAllTimelines()
                    ├── startLessonActivity(json)
                    ├── updateLessonActivity(json)
                    ├── endLessonActivity()
                    ├── startSubstitutionActivity(json)
                    └── endSubstitutionActivity()

iOS Targets:
  ├── LanisWidgets (Widget Extension)
  │     ├── StundenplanWidget
  │     ├── VertretungsWidget
  │     ├── KalenderWidget
  │     └── NachrichtenWidget
  └── LanisLiveActivities (ActivityKit, selbe Extension oder separat)
        ├── StundenLiveActivity
        └── VertretungsLiveActivity
```

### Datenpipe

Flutter schreibt bei jedem App-Start, App-Refresh und Background-Fetch JSON in `UserDefaults(suiteName: "group.io.github.alessioc42.sph.widgets")`. Die Widget Extension liest daraus — kein eigenständiger Netzwerkzugriff im Widget.

**Fallback:** WidgetKit fordert alle 30–60 Minuten einen neuen Timeline-Snapshot an. Der `TimelineProvider` liest dabei erneut aus UserDefaults (gecachte Daten, kein Netzwerk).

---

## Flutter-Integration

### `lib/core/widget_data_service.dart`

Neues Singleton. Öffentliche API:

```dart
class WidgetDataService {
  static final instance = WidgetDataService._();

  Future<void> updateAll(SPH sph, AccountType accountType);
  Future<void> updateTimetable(SPH sph);
  Future<void> updateSubstitutions(SPH sph);
  Future<void> updateCalendar(SPH sph);
  Future<void> updateConversations(SPH sph);

  Future<void> startLessonActivity(TimetableSubject current, TimetableSubject? next);
  Future<void> updateLessonActivity(TimetableSubject current, TimetableSubject? next);
  Future<void> endLessonActivity();

  Future<void> startSubstitutionActivity(List<Substitution> newEntries);
  Future<void> endSubstitutionActivity();
}
```

Nutzt `MethodChannel('io.github.alessioc42.sph/widgets')` für alle nativen Calls. Nur auf iOS aktiv (`Platform.isIOS`).

### Einbindung

- `startup.dart`: `WidgetDataService.instance.updateAll(...)` nach Login
- `background_service.dart` (`callbackDispatcher`): nach jedem erfolgreichen Parser-Refresh
- Nach jedem manuellen Pull-to-Refresh in den Applet-Views

---

## Datenformate (App Group UserDefaults)

### `widget_timetable`
```json
{
  "updatedAt": "2024-01-15T08:00:00Z",
  "today": [
    {
      "name": "Mathematik",
      "room": "R204",
      "teacher": "Müller",
      "start": "08:00",
      "end": "08:45",
      "stunde": 1,
      "color": "#6750A4"
    }
  ],
  "currentLesson": null
}
```

### `widget_substitutions`
```json
{
  "updatedAt": "2024-01-15T08:00:00Z",
  "date": "15.01.2024",
  "entries": [
    {
      "stunde": "3",
      "fach": "Englisch",
      "art": "Vertretung",
      "raum": "R105",
      "vertreter": "Schmidt"
    }
  ]
}
```

### `widget_calendar`
```json
{
  "updatedAt": "2024-01-15T08:00:00Z",
  "events": [
    {
      "title": "Klassenarbeit Mathe",
      "start": "2024-01-20T08:00:00Z",
      "allDay": false,
      "color": "#4242FC"
    }
  ]
}
```

### `widget_conversations`
```json
{
  "updatedAt": "2024-01-15T08:00:00Z",
  "unreadCount": 3,
  "latest": [
    {
      "sender": "Hr. Müller",
      "subject": "Hausaufgaben",
      "isUnread": true
    }
  ]
}
```

### `live_activity_lesson`
```json
{
  "name": "Mathematik",
  "room": "R204",
  "teacher": "Müller",
  "start": "08:00",
  "end": "08:45",
  "nextName": "Deutsch",
  "nextStart": "09:00"
}
```

### `live_activity_substitutions`
```json
{
  "date": "15.01.2024",
  "newEntries": [
    { "stunde": "3", "fach": "Englisch", "art": "Vertretung" }
  ]
}
```

---

## Widget-Definitionen

### Design-Sprache

- **Hintergrund:** `containerBackground` (iOS 17+) / System-Material (Fallback)
- **Akzentfarbe:** App `accentColor` aus Bundle — passt sich dem vom Nutzer gewählten Theme an
- **Typographie:** SF Pro (iOS-Standard)
- **Logo:** App-Icon klein oben links in jedem Widget
- **Versionsgards:** `#available(iOS 16, *)` für Lock Screen, `#available(iOS 16.2, *)` für Live Activities

---

### StundenplanWidget

| Größe | Inhalt |
|-------|--------|
| Small | App-Icon + Fachname + Uhrzeit der nächsten/aktuellen Stunde |
| Medium | Aktuelle Stunde (Fach, Raum, Lehrer) + nächste 1–2 Stunden als Liste |
| Large | Heutige Stunden als kompakte Liste (Uhrzeit, Fach, Raum) |
| Lock Screen Circular | Fachkürzel der aktuellen/nächsten Stunde |
| Lock Screen Rectangular | Fach + Uhrzeit einzeilig |
| Lock Screen Inline | „Jetzt: Mathe R204" |

---

### VertretungsWidget

| Größe | Inhalt |
|-------|--------|
| Small | Anzahl heutiger Vertretungen + erste Stunde |
| Medium | Bis zu 3 Vertretungen (Stunde, Fach, Art) als Liste |
| Large | Alle heutigen Vertretungen mit Details (Fach, Art, Raum, Vertreter) |
| Lock Screen Circular | Anzahl-Badge |
| Lock Screen Rectangular | Erste Vertretung (Stunde + Art) |
| Lock Screen Inline | „3 Vertretungen heute" |

---

### KalenderWidget

| Größe | Inhalt |
|-------|--------|
| Small | Nächstes Ereignis (Titel + Datum) |
| Medium | Nächste 3 Ereignisse mit Datum |
| Large | Nächste 5–7 Ereignisse, gruppiert nach Tag |
| Lock Screen Circular | Tages-Countdown (in X Tagen) |
| Lock Screen Rectangular | Titel des nächsten Ereignisses |
| Lock Screen Inline | „Morgen: Klassenarbeit Mathe" |

---

### NachrichtenWidget

| Größe | Inhalt |
|-------|--------|
| Small | Anzahl ungelesener Nachrichten |
| Medium | Neueste 2 Nachrichten (Absender + Betreff-Vorschau) |
| Large | Neueste 5 Nachrichten mit Ungelesen-Markierung |
| Lock Screen Circular | Ungelesen-Anzahl als Badge |
| Lock Screen Rectangular | Absender + Betreff der neuesten Nachricht |
| Lock Screen Inline | „3 ungelesene Nachrichten" |

---

## Live Activities

### StundenLiveActivity

**Attributes (statisch):**
- `lessonName: String`
- `teacher: String`
- `room: String`

**ContentState (dynamisch):**
- `endTime: Date` (für Countdown via `.timer`)
- `nextLessonName: String?`
- `nextLessonStart: String?`

**UI:**
| Bereich | Inhalt |
|---------|--------|
| Dynamic Island Compact Leading | Fachkürzel (2–3 Zeichen) |
| Dynamic Island Compact Trailing | Countdown-Timer |
| Dynamic Island Minimal | Fachkürzel |
| Dynamic Island Expanded | Fach + Raum + Lehrer, Fortschrittsbalken der Stunde, nächste Stunde |
| Lock Screen Banner | Fach, Raum, verbleibende Zeit als Fortschrittsbalken |

---

### VertretungsLiveActivity

**Attributes (statisch):**
- `date: String`

**ContentState (dynamisch):**
- `entries: [SubstitutionEntry]` (Stunde, Fach, Art)
- `count: Int`

**UI:**
| Bereich | Inhalt |
|---------|--------|
| Dynamic Island Compact Leading | ⚠️ Symbol |
| Dynamic Island Compact Trailing | Anzahl neuer Vertretungen |
| Dynamic Island Minimal | Anzahl |
| Dynamic Island Expanded | Liste der neuen Vertretungen (Stunde, Fach, Art) |
| Lock Screen Banner | „X neue Vertretung(en)" + erste Änderung |

---

## Dateien & Targets

### Neue Dart-Dateien
- `lib/core/widget_data_service.dart` — WidgetDataService Singleton

### Neue Swift-Dateien (Runner Target)
- `ios/Runner/WidgetChannel.swift` — MethodChannel Handler

### Neues Xcode Target: `LanisWidgets`
- `ios/LanisWidgets/LanisWidgetsBundle.swift` — Widget Bundle
- `ios/LanisWidgets/StundenplanWidget.swift`
- `ios/LanisWidgets/VertretungsWidget.swift`
- `ios/LanisWidgets/KalenderWidget.swift`
- `ios/LanisWidgets/NachrichtenWidget.swift`
- `ios/LanisWidgets/SharedModels.swift` — gemeinsame Datenmodelle (Decodable)
- `ios/LanisWidgets/WidgetDataReader.swift` — liest App Group UserDefaults
- `ios/LanisWidgets/Views/` — SwiftUI View-Komponenten pro Widget/Größe

### Neues Xcode Target: `LanisLiveActivities` (oder Teil von LanisWidgets)
- `ios/LanisWidgets/StundenLiveActivity.swift`
- `ios/LanisWidgets/VertretungsLiveActivity.swift`
- `ios/LanisWidgets/LiveActivityAttributes.swift`

### Xcode-Konfiguration
- App Group `group.io.github.alessioc42.sph.widgets` in Runner + Widget Extension aktivieren
- `NSSupportsLiveActivities: YES` in Runner Info.plist
- Podfile: `platform :ios, '14.0'` (Widget-Minimum)

---

## iOS-Versions-Guards

```swift
// Widgets: immer verfügbar (iOS 14+)
// Lock Screen Widgets:
if #available(iOS 16.0, *) { /* Accessory families */ }
// Live Activities:
if #available(iOS 16.2, *) { /* ActivityKit */ }
```

---

## Nicht im Scope

- Lehrer-Account-Widgets (nur Schüler-Daten)
- Widget-seitiger Netzwerkzugriff / eigene Auth
- Android-Widgets (separates Feature)
- Interaktive Widgets (iOS 17 Widget Interactions)
