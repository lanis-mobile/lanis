# iOS Widgets & Live Activities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Native iOS Home-Screen-Widgets (Stundenplan, Vertretungen, Kalender, Nachrichten) und Live Activities (laufende Stunde, neue Vertretungen) für die lanis-App.

**Architecture:** Flutter schreibt JSON-Daten via MethodChannel in eine App Group UserDefaults-Datenbank. Eine native SwiftUI Widget Extension liest daraus und rendert Widgets in allen Größen. Live Activities werden via ActivityKit aus Flutter gesteuert.

**Tech Stack:** Flutter/Dart (MethodChannel), Swift/SwiftUI (WidgetKit, ActivityKit), App Groups (UserDefaults), iOS 14+ (Widgets), iOS 16+ (Lock Screen), iOS 16.2+ (Live Activities)

---

## Dateien-Übersicht

### Neue Dart-Dateien
- `lib/core/widget_data_service.dart` — Singleton, schreibt Daten in App Group, steuert Live Activities

### Geänderte Dart-Dateien
- `lib/utils/authentication_state.dart` — `updateAll()` nach erfolgreichem Login aufrufen
- `lib/background_service.dart` — `updateAll()` nach Background-Fetch aufrufen

### Neue Swift-Dateien (Runner Target)
- `ios/Runner/WidgetChannel.swift` — MethodChannel Handler für alle nativen Widget-Operationen

### Neue Swift-Dateien (LanisWidgets Extension Target)
- `ios/LanisWidgets/LanisWidgetsBundle.swift` — Entry point für Widget Extension
- `ios/LanisWidgets/SharedModels.swift` — `Decodable` Datenmodelle (TimetableEntry, SubstitutionEntry, CalendarEvent, ConversationEntry)
- `ios/LanisWidgets/WidgetDataReader.swift` — liest und dekodiert JSON aus App Group UserDefaults
- `ios/LanisWidgets/StundenplanWidget.swift` — Widget + Timeline Provider + SwiftUI Views
- `ios/LanisWidgets/VertretungsWidget.swift` — Widget + Timeline Provider + SwiftUI Views
- `ios/LanisWidgets/KalenderWidget.swift` — Widget + Timeline Provider + SwiftUI Views
- `ios/LanisWidgets/NachrichtenWidget.swift` — Widget + Timeline Provider + SwiftUI Views
- `ios/LanisWidgets/LiveActivityAttributes.swift` — ActivityAttributes für beide Live Activities
- `ios/LanisWidgets/StundenLiveActivity.swift` — SwiftUI Views für Stunden-Live-Activity
- `ios/LanisWidgets/VertretungsLiveActivity.swift` — SwiftUI Views für Vertretungs-Live-Activity

### Geänderte Xcode-Dateien
- `ios/Runner/Info.plist` — `NSSupportsLiveActivities: YES`
- `ios/Runner/AppDelegate.swift` — WidgetChannel registrieren
- `ios/Podfile` — (keine Änderung nötig, Extension bekommt eigenes Deployment Target in Xcode)

---

## Task 1: Xcode — Widget Extension Target anlegen

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (via Xcode GUI)
- Create: `ios/LanisWidgets/LanisWidgetsBundle.swift`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Widget Extension in Xcode anlegen**

  In Xcode: File → New → Target → Widget Extension
  - Product Name: `LanisWidgets`
  - Bundle Identifier: `io.github.alessioc42.sph.widgets`
  - Include Live Activity: ✓ (ankreuzen)
  - Include Configuration Intent: ✗
  - Deployment Target: iOS 14.0
  - Xcode erstellt automatisch einen Placeholder-Widget — dieser wird in Task 4 ersetzt.

- [ ] **Step 2: App Group aktivieren**

  In Xcode Signing & Capabilities:
  - Runner Target → + Capability → App Groups → `group.io.github.alessioc42.sph.widgets` hinzufügen
  - LanisWidgets Target → + Capability → App Groups → dieselbe Group hinzufügen

- [ ] **Step 3: Live Activities in Info.plist aktivieren**

  `ios/Runner/Info.plist` — folgenden Eintrag hinzufügen (vor dem letzten `</dict>`):
  ```xml
  <key>NSSupportsLiveActivities</key>
  <true/>
  <key>NSSupportsLiveActivitiesFrequentUpdates</key>
  <true/>
  ```

- [ ] **Step 4: Bundle-Datei anlegen**

  `ios/LanisWidgets/LanisWidgetsBundle.swift`:
  ```swift
  import WidgetKit
  import SwiftUI

  @main
  struct LanisWidgetsBundle: WidgetBundle {
      var body: some Widget {
          StundenplanWidget()
          VertretungsWidget()
          KalenderWidget()
          NachrichtenWidget()
          if #available(iOSApplicationExtension 16.2, *) {
              StundenLiveActivityWidget()
              VertretungsLiveActivityWidget()
          }
      }
  }
  ```

- [ ] **Step 5: Build prüfen**

  ```bash
  cd /Users/I767513/lanis
  flutter build ios --no-codesign 2>&1 | tail -20
  ```
  Erwartet: Build läuft durch (oder schlägt nur wegen Signing fehl, nicht wegen Kompilierfehlern)

- [ ] **Step 6: Commit**

  ```bash
  git add ios/
  git commit -m "feat(ios): add LanisWidgets extension target with App Group"
  ```

---

## Task 2: Swift — SharedModels & WidgetDataReader

**Files:**
- Create: `ios/LanisWidgets/SharedModels.swift`
- Create: `ios/LanisWidgets/WidgetDataReader.swift`

- [ ] **Step 1: SharedModels anlegen**

  `ios/LanisWidgets/SharedModels.swift`:
  ```swift
  import Foundation
  import SwiftUI

  let appGroupID = "group.io.github.alessioc42.sph.widgets"

  struct TimetableEntry: Decodable {
      let name: String
      let room: String?
      let teacher: String?
      let start: String
      let end: String
      let stunde: Int
      let color: String?

      var accentColor: Color {
          guard let hex = color else { return .accentColor }
          return Color(hex: hex) ?? .accentColor
      }
  }

  struct TimetableData: Decodable {
      let updatedAt: String
      let today: [TimetableEntry]
      let currentLesson: TimetableEntry?
  }

  struct SubstitutionEntry: Decodable {
      let stunde: String
      let fach: String?
      let art: String?
      let raum: String?
      let vertreter: String?
  }

  struct SubstitutionData: Decodable {
      let updatedAt: String
      let date: String
      let entries: [SubstitutionEntry]
  }

  struct CalendarEventEntry: Decodable {
      let title: String
      let start: String
      let allDay: Bool
      let color: String?

      var startDate: Date? {
          ISO8601DateFormatter().date(from: start)
      }

      var accentColor: Color {
          guard let hex = color else { return .accentColor }
          return Color(hex: hex) ?? .accentColor
      }
  }

  struct CalendarData: Decodable {
      let updatedAt: String
      let events: [CalendarEventEntry]
  }

  struct ConversationEntry: Decodable {
      let sender: String
      let subject: String
      let isUnread: Bool
  }

  struct ConversationsData: Decodable {
      let updatedAt: String
      let unreadCount: Int
      let latest: [ConversationEntry]
  }

  // MARK: - Color from Hex helper
  extension Color {
      init?(hex: String) {
          let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
          var int: UInt64 = 0
          Scanner(string: hex).scanHexInt64(&int)
          let r, g, b: Double
          switch hex.count {
          case 6:
              r = Double((int >> 16) & 0xFF) / 255
              g = Double((int >> 8) & 0xFF) / 255
              b = Double(int & 0xFF) / 255
          default:
              return nil
          }
          self.init(red: r, green: g, blue: b)
      }
  }
  ```

- [ ] **Step 2: WidgetDataReader anlegen**

  `ios/LanisWidgets/WidgetDataReader.swift`:
  ```swift
  import Foundation

  struct WidgetDataReader {
      private static let defaults = UserDefaults(suiteName: appGroupID)

      static func timetable() -> TimetableData? {
          decode(key: "widget_timetable")
      }

      static func substitutions() -> SubstitutionData? {
          decode(key: "widget_substitutions")
      }

      static func calendar() -> CalendarData? {
          decode(key: "widget_calendar")
      }

      static func conversations() -> ConversationsData? {
          decode(key: "widget_conversations")
      }

      private static func decode<T: Decodable>(key: String) -> T? {
          guard let jsonString = defaults?.string(forKey: key),
                let data = jsonString.data(using: .utf8) else { return nil }
          return try? JSONDecoder().decode(T.self, from: data)
      }
  }
  ```

- [ ] **Step 3: Build prüfen**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -20
  ```
  Erwartet: Keine Kompilierfehler in LanisWidgets

- [ ] **Step 4: Commit**

  ```bash
  git add ios/LanisWidgets/SharedModels.swift ios/LanisWidgets/WidgetDataReader.swift
  git commit -m "feat(ios): add shared widget models and data reader"
  ```

---

## Task 3: Swift — MethodChannel (WidgetChannel)

**Files:**
- Create: `ios/Runner/WidgetChannel.swift`
- Modify: `ios/Runner/AppDelegate.swift`

- [ ] **Step 1: WidgetChannel anlegen**

  `ios/Runner/WidgetChannel.swift`:
  ```swift
  import Flutter
  import WidgetKit
  import ActivityKit

  class WidgetChannel {
      static let channelName = "io.github.alessioc42.sph/widgets"
      private static let defaults = UserDefaults(suiteName: "group.io.github.alessioc42.sph.widgets")

      static func register(with controller: FlutterViewController) {
          let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
          channel.setMethodCallHandler { call, result in
              switch call.method {
              case "writeData":
                  guard let args = call.arguments as? [String: String],
                        let key = args["key"], let value = args["value"] else {
                      result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                      return
                  }
                  defaults?.set(value, forKey: key)
                  result(nil)

              case "reloadWidgets":
                  if #available(iOS 14.0, *) {
                      WidgetCenter.shared.reloadAllTimelines()
                  }
                  result(nil)

              case "startLessonActivity":
                  if #available(iOS 16.2, *) {
                      guard let json = call.arguments as? String else {
                          result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                          return
                      }
                      LessonActivityManager.start(json: json, result: result)
                  } else {
                      result(nil)
                  }

              case "updateLessonActivity":
                  if #available(iOS 16.2, *) {
                      guard let json = call.arguments as? String else {
                          result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                          return
                      }
                      LessonActivityManager.update(json: json, result: result)
                  } else {
                      result(nil)
                  }

              case "endLessonActivity":
                  if #available(iOS 16.2, *) {
                      LessonActivityManager.end(result: result)
                  } else {
                      result(nil)
                  }

              case "startSubstitutionActivity":
                  if #available(iOS 16.2, *) {
                      guard let json = call.arguments as? String else {
                          result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                          return
                      }
                      SubstitutionActivityManager.start(json: json, result: result)
                  } else {
                      result(nil)
                  }

              case "endSubstitutionActivity":
                  if #available(iOS 16.2, *) {
                      SubstitutionActivityManager.end(result: result)
                  } else {
                      result(nil)
                  }

              default:
                  result(FlutterMethodNotImplemented)
              }
          }
      }
  }
  ```

- [ ] **Step 2: AppDelegate anpassen**

  `ios/Runner/AppDelegate.swift` — `WidgetChannel.register` nach `super.application(...)`:
  ```swift
  import UIKit
  import Flutter
  import flutter_local_notifications

  @main
  @objc class AppDelegate: FlutterAppDelegate {
    override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
      GeneratedPluginRegistrant.register(with: self)

      if #available(iOS 13.0, *) {
        UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
      }

      FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
      }

      if let controller = window?.rootViewController as? FlutterViewController {
          WidgetChannel.register(with: controller)
      }

      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
  }
  ```

- [ ] **Step 3: Build prüfen**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -20
  ```
  Erwartet: Keine Fehler

- [ ] **Step 4: Commit**

  ```bash
  git add ios/Runner/WidgetChannel.swift ios/Runner/AppDelegate.swift
  git commit -m "feat(ios): register widget MethodChannel in AppDelegate"
  ```

---

## Task 4: Dart — WidgetDataService

**Files:**
- Create: `lib/core/widget_data_service.dart`

- [ ] **Step 1: WidgetDataService anlegen**

  `lib/core/widget_data_service.dart`:
  ```dart
  import 'dart:convert';
  import 'dart:io';

  import 'package:flutter/services.dart';

  import '../sph/sph.dart';
  import '../../models/account_types.dart';
  import '../../models/timetable.dart';
  import '../../utils/logger.dart';

  class WidgetDataService {
    WidgetDataService._();
    static final instance = WidgetDataService._();

    static const _channel = MethodChannel('io.github.alessioc42.sph/widgets');

    bool get _isIOS => Platform.isIOS;

    Future<void> _write(String key, Map<String, dynamic> data) async {
      if (!_isIOS) return;
      try {
        await _channel.invokeMethod('writeData', {
          'key': key,
          'value': jsonEncode(data),
        });
      } catch (e) {
        logger.w('WidgetDataService: writeData failed for $key: $e');
      }
    }

    Future<void> _reloadWidgets() async {
      if (!_isIOS) return;
      try {
        await _channel.invokeMethod('reloadWidgets');
      } catch (e) {
        logger.w('WidgetDataService: reloadWidgets failed: $e');
      }
    }

    Future<void> updateAll(SPH sph, AccountType accountType) async {
      if (!_isIOS) return;
      await Future.wait([
        updateTimetable(sph),
        updateSubstitutions(sph),
        updateCalendar(sph),
        updateConversations(sph),
      ]);
      await _reloadWidgets();
    }

    Future<void> updateTimetable(SPH sph) async {
      if (!_isIOS) return;
      try {
        final data = await sph.parser.timetableStudentParser.getHome();
        final now = TimeOfDay.now();
        final today = _getTodayLessons(data);

        TimetableSubject? current;
        for (final lesson in today) {
          if (_isOngoing(lesson, now)) {
            current = lesson;
            break;
          }
        }

        await _write('widget_timetable', {
          'updatedAt': DateTime.now().toIso8601String(),
          'today': today.map((l) => _lessonToJson(l)).toList(),
          'currentLesson': current != null ? _lessonToJson(current) : null,
        });
      } catch (e) {
        logger.w('WidgetDataService: updateTimetable failed: $e');
      }
    }

    Future<void> updateSubstitutions(SPH sph) async {
      if (!_isIOS) return;
      try {
        final plan = await sph.parser.substitutionsParser.getHome();
        final today = plan.days.isNotEmpty ? plan.days.first : null;
        final entries = today?.substitutions ?? [];

        await _write('widget_substitutions', {
          'updatedAt': DateTime.now().toIso8601String(),
          'date': today?.parsedDate ?? '',
          'entries': entries
              .map((s) => {
                    'stunde': s.stunde,
                    'fach': s.fach,
                    'art': s.art,
                    'raum': s.raum,
                    'vertreter': s.vertreter,
                  })
              .toList(),
        });
      } catch (e) {
        logger.w('WidgetDataService: updateSubstitutions failed: $e');
      }
    }

    Future<void> updateCalendar(SPH sph) async {
      if (!_isIOS) return;
      try {
        final events = await sph.parser.calendarParser.getHome();
        final upcoming = events
            .where((e) => e.endTime.isAfter(DateTime.now()))
            .take(10)
            .toList();

        await _write('widget_calendar', {
          'updatedAt': DateTime.now().toIso8601String(),
          'events': upcoming
              .map((e) => {
                    'title': e.title,
                    'start': e.startTime.toIso8601String(),
                    'allDay': e.allDay,
                    'color':
                        '#${e.color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
                  })
              .toList(),
        });
      } catch (e) {
        logger.w('WidgetDataService: updateCalendar failed: $e');
      }
    }

    Future<void> updateConversations(SPH sph) async {
      if (!_isIOS) return;
      try {
        final entries = await sph.parser.conversationsParser.getHome();
        final unread = entries.where((e) => e.unread).length;

        await _write('widget_conversations', {
          'updatedAt': DateTime.now().toIso8601String(),
          'unreadCount': unread,
          'latest': entries
              .take(5)
              .map((e) => {
                    'sender': e.fullName,
                    'subject': e.title,
                    'isUnread': e.unread,
                  })
              .toList(),
        });
      } catch (e) {
        logger.w('WidgetDataService: updateConversations failed: $e');
      }
    }

    // Live Activity — Stunde
    Future<void> startLessonActivity(
        TimetableSubject current, TimetableSubject? next) async {
      if (!_isIOS) return;
      try {
        await _channel.invokeMethod(
            'startLessonActivity', jsonEncode(_lessonActivityJson(current, next)));
      } catch (e) {
        logger.w('WidgetDataService: startLessonActivity failed: $e');
      }
    }

    Future<void> updateLessonActivity(
        TimetableSubject current, TimetableSubject? next) async {
      if (!_isIOS) return;
      try {
        await _channel.invokeMethod('updateLessonActivity',
            jsonEncode(_lessonActivityJson(current, next)));
      } catch (e) {
        logger.w('WidgetDataService: updateLessonActivity failed: $e');
      }
    }

    Future<void> endLessonActivity() async {
      if (!_isIOS) return;
      try {
        await _channel.invokeMethod('endLessonActivity');
      } catch (e) {
        logger.w('WidgetDataService: endLessonActivity failed: $e');
      }
    }

    // Live Activity — Vertretungen
    Future<void> startSubstitutionActivity(
        List<Map<String, String?>> entries) async {
      if (!_isIOS) return;
      try {
        final json = jsonEncode({
          'date': DateTime.now().toIso8601String(),
          'newEntries': entries,
        });
        await _channel.invokeMethod('startSubstitutionActivity', json);
      } catch (e) {
        logger.w('WidgetDataService: startSubstitutionActivity failed: $e');
      }
    }

    Future<void> endSubstitutionActivity() async {
      if (!_isIOS) return;
      try {
        await _channel.invokeMethod('endSubstitutionActivity');
      } catch (e) {
        logger.w('WidgetDataService: endSubstitutionActivity failed: $e');
      }
    }

    // Helpers
    List<TimetableSubject> _getTodayLessons(TimeTable data) {
      final today = data.planForOwn ?? data.planForAll ?? [];
      final dayIndex = DateTime.now().weekday - 1; // 0=Mo
      if (dayIndex < 0 || dayIndex >= today.length) return [];
      return today[dayIndex];
    }

    bool _isOngoing(TimetableSubject lesson, TimeOfDay now) {
      final startMinutes =
          lesson.startTime.hour * 60 + lesson.startTime.minute;
      final endMinutes = lesson.endTime.hour * 60 + lesson.endTime.minute;
      final nowMinutes = now.hour * 60 + now.minute;
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }

    Map<String, dynamic> _lessonToJson(TimetableSubject l) => {
          'name': l.name ?? '',
          'room': l.raum,
          'teacher': l.lehrer,
          'start':
              '${l.startTime.hour.toString().padLeft(2, '0')}:${l.startTime.minute.toString().padLeft(2, '0')}',
          'end':
              '${l.endTime.hour.toString().padLeft(2, '0')}:${l.endTime.minute.toString().padLeft(2, '0')}',
          'stunde': l.stunde ?? 0,
          'color': null,
        };

    Map<String, dynamic> _lessonActivityJson(
        TimetableSubject current, TimetableSubject? next) {
      return {
        'name': current.name ?? '',
        'room': current.raum,
        'teacher': current.lehrer,
        'start':
            '${current.startTime.hour.toString().padLeft(2, '0')}:${current.startTime.minute.toString().padLeft(2, '0')}',
        'end':
            '${current.endTime.hour.toString().padLeft(2, '0')}:${current.endTime.minute.toString().padLeft(2, '0')}',
        'nextName': next?.name,
        'nextStart': next != null
            ? '${next.startTime.hour.toString().padLeft(2, '0')}:${next.startTime.minute.toString().padLeft(2, '0')}'
            : null,
      };
    }
  }
  ```

  > Hinweis: `TimeTable` hat `planForOwn` und `planForAll` als `List<List<TimetableSubject>>?` — ein inneres `List<TimetableSubject>` pro Wochentag. Wir nutzen `planForOwn ?? planForAll`.

- [ ] **Step 2: Dart-Analyse prüfen**

  ```bash
  cd /Users/I767513/lanis
  dart analyze lib/core/widget_data_service.dart
  ```
  Erwartet: Keine Errors (Warnings bzgl. fehlender Imports sind ok, werden in nächsten Tasks aufgelöst)

- [ ] **Step 3: Commit**

  ```bash
  git add lib/core/widget_data_service.dart
  git commit -m "feat: add WidgetDataService for iOS widget data bridge"
  ```

---

## Task 5: Dart — WidgetDataService in App-Flow einbinden

**Files:**
- Modify: `lib/utils/authentication_state.dart`
- Modify: `lib/background_service.dart`

- [ ] **Step 1: Nach Login aufrufen**

  `lib/utils/authentication_state.dart` — Import hinzufügen und `updateAll` nach erfolgreichem Login aufrufen:
  ```dart
  // bestehende Imports...
  import 'package:lanis/core/widget_data_service.dart';
  ```

  In der `login()`-Methode, nach `status.value = LoginStatus.done;` (innerhalb des try-Blocks, nach `homeKey.currentState?.resetState()`):
  ```dart
  if (exception.value == null) {
    status.value = LoginStatus.done;
    // Widget-Daten im Hintergrund aktualisieren
    if (sph != null) {
      WidgetDataService.instance
          .updateAll(sph!, sph!.session.accountType)
          .ignore();
    }
  }
  ```

- [ ] **Step 2: Im Background-Task aufrufen**

  `lib/background_service.dart` — Import hinzufügen:
  ```dart
  import 'package:lanis/core/widget_data_service.dart';
  ```

  In `callbackDispatcher()`, nach dem letzten `notificationTask` Aufruf (am Ende des for-each über Accounts), füge Folgendes hinzu:
  ```dart
  await WidgetDataService.instance.updateAll(sph, accountType);
  ```

  > Stelle sicher, dass `WidgetDataService.instance.updateAll(...)` nach dem bestehenden `if (notificationTask != null)` Block aufgerufen wird, damit Widget-Daten auch ohne aktivierte Notifications aktualisiert werden.

- [ ] **Step 3: Dart-Analyse prüfen**

  ```bash
  dart analyze lib/utils/authentication_state.dart lib/background_service.dart
  ```
  Erwartet: Keine Errors

- [ ] **Step 4: Build prüfen**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -20
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add lib/utils/authentication_state.dart lib/background_service.dart
  git commit -m "feat: trigger widget data update on login and background fetch"
  ```

---

## Task 6: Swift — Live Activity Attributes & Manager

**Files:**
- Create: `ios/LanisWidgets/LiveActivityAttributes.swift`
- Create: `ios/Runner/LessonActivityManager.swift`
- Create: `ios/Runner/SubstitutionActivityManager.swift`

- [ ] **Step 1: LiveActivityAttributes anlegen**

  `ios/LanisWidgets/LiveActivityAttributes.swift`:
  ```swift
  import ActivityKit
  import Foundation

  // MARK: - Stunden Live Activity
  @available(iOS 16.2, *)
  struct LessonActivityAttributes: ActivityAttributes {
      public struct ContentState: Codable, Hashable {
          var endTime: Date
          var nextLessonName: String?
          var nextLessonStart: String?
      }

      var lessonName: String
      var teacher: String?
      var room: String?
  }

  // MARK: - Vertretungs Live Activity
  struct LiveSubstitutionEntry: Codable, Hashable {
      let stunde: String
      let fach: String?
      let art: String?
  }

  @available(iOS 16.2, *)
  struct SubstitutionActivityAttributes: ActivityAttributes {
      public struct ContentState: Codable, Hashable {
          var entries: [LiveSubstitutionEntry]
          var count: Int
      }

      var date: String
  }
  ```

- [ ] **Step 2: LessonActivityManager anlegen**

  `ios/Runner/LessonActivityManager.swift`:
  ```swift
  import ActivityKit
  import Flutter
  import Foundation

  @available(iOS 16.2, *)
  struct LessonJson: Decodable {
      let name: String
      let room: String?
      let teacher: String?
      let end: String  // "HH:mm"
      let nextName: String?
      let nextStart: String?
  }

  @available(iOS 16.2, *)
  enum LessonActivityManager {
      private static var currentActivity: Activity<LessonActivityAttributes>?

      static func start(json: String, result: @escaping FlutterResult) {
          guard let data = json.data(using: .utf8),
                let lesson = try? JSONDecoder().decode(LessonJson.self, from: data),
                let endDate = parseTime(lesson.end)
          else {
              result(FlutterError(code: "PARSE_ERROR", message: "Could not parse lesson json", details: nil))
              return
          }

          let attrs = LessonActivityAttributes(
              lessonName: lesson.name,
              teacher: lesson.teacher,
              room: lesson.room
          )
          let state = LessonActivityAttributes.ContentState(
              endTime: endDate,
              nextLessonName: lesson.nextName,
              nextLessonStart: lesson.nextStart
          )

          do {
              currentActivity = try Activity.request(
                  attributes: attrs,
                  contentState: state,
                  pushType: nil
              )
              result(nil)
          } catch {
              result(FlutterError(code: "ACTIVITY_ERROR", message: error.localizedDescription, details: nil))
          }
      }

      static func update(json: String, result: @escaping FlutterResult) {
          guard let activity = currentActivity,
                let data = json.data(using: .utf8),
                let lesson = try? JSONDecoder().decode(LessonJson.self, from: data),
                let endDate = parseTime(lesson.end)
          else {
              result(nil)
              return
          }

          let state = LessonActivityAttributes.ContentState(
              endTime: endDate,
              nextLessonName: lesson.nextName,
              nextLessonStart: lesson.nextStart
          )
          Task {
              await activity.update(using: state)
              result(nil)
          }
      }

      static func end(result: @escaping FlutterResult) {
          guard let activity = currentActivity else {
              result(nil)
              return
          }
          Task {
              await activity.end(dismissalPolicy: .immediate)
              currentActivity = nil
              result(nil)
          }
      }

      private static func parseTime(_ timeString: String) -> Date? {
          let parts = timeString.split(separator: ":").compactMap { Int($0) }
          guard parts.count == 2 else { return nil }
          let calendar = Calendar.current
          var components = calendar.dateComponents([.year, .month, .day], from: Date())
          components.hour = parts[0]
          components.minute = parts[1]
          components.second = 0
          return calendar.date(from: components)
      }
  }
  ```

- [ ] **Step 3: SubstitutionActivityManager anlegen**

  `ios/Runner/SubstitutionActivityManager.swift`:
  ```swift
  import ActivityKit
  import Flutter
  import Foundation

  @available(iOS 16.2, *)
  struct SubstitutionActivityJson: Decodable {
      let date: String
      let newEntries: [LiveSubstitutionEntry]
  }

  @available(iOS 16.2, *)
  enum SubstitutionActivityManager {
      private static var currentActivity: Activity<SubstitutionActivityAttributes>?

      static func start(json: String, result: @escaping FlutterResult) {
          guard let data = json.data(using: .utf8),
                let payload = try? JSONDecoder().decode(SubstitutionActivityJson.self, from: data)
          else {
              result(FlutterError(code: "PARSE_ERROR", message: "Could not parse substitution json", details: nil))
              return
          }

          let attrs = SubstitutionActivityAttributes(date: payload.date)
          let state = SubstitutionActivityAttributes.ContentState(
              entries: payload.newEntries,
              count: payload.newEntries.count
          )

          do {
              currentActivity = try Activity.request(
                  attributes: attrs,
                  contentState: state,
                  pushType: nil
              )
              result(nil)
          } catch {
              result(FlutterError(code: "ACTIVITY_ERROR", message: error.localizedDescription, details: nil))
          }
      }

      static func end(result: @escaping FlutterResult) {
          guard let activity = currentActivity else {
              result(nil)
              return
          }
          Task {
              await activity.end(dismissalPolicy: .immediate)
              currentActivity = nil
              result(nil)
          }
      }
  }
  ```

- [ ] **Step 4: Build prüfen**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -20
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add ios/LanisWidgets/LiveActivityAttributes.swift \
          ios/Runner/LessonActivityManager.swift \
          ios/Runner/SubstitutionActivityManager.swift
  git commit -m "feat(ios): add Live Activity attributes and managers"
  ```

---

## Task 7: Swift — StundenplanWidget

**Files:**
- Modify: `ios/LanisWidgets/StundenplanWidget.swift` (Xcode-Placeholder ersetzen)

- [ ] **Step 1: StundenplanWidget implementieren**

  `ios/LanisWidgets/StundenplanWidget.swift` komplett ersetzen:
  ```swift
  import WidgetKit
  import SwiftUI

  struct TimetableTimelineEntry: TimelineEntry {
      let date: Date
      let data: TimetableData?
  }

  struct TimetableProvider: TimelineProvider {
      func placeholder(in context: Context) -> TimetableTimelineEntry {
          TimetableTimelineEntry(date: Date(), data: nil)
      }

      func getSnapshot(in context: Context, completion: @escaping (TimetableTimelineEntry) -> Void) {
          completion(TimetableTimelineEntry(date: Date(), data: WidgetDataReader.timetable()))
      }

      func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableTimelineEntry>) -> Void) {
          let entry = TimetableTimelineEntry(date: Date(), data: WidgetDataReader.timetable())
          let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
          completion(Timeline(entries: [entry], policy: .after(next)))
      }
  }

  // MARK: - Small View
  struct TimetableSmallView: View {
      let data: TimetableData?

      private var relevantLesson: TimetableEntry? {
          data?.currentLesson ?? data?.today.first(where: { isUpcoming($0) })
      }

      var body: some View {
          VStack(alignment: .leading, spacing: 4) {
              HStack {
                  Image("AppIcon")
                      .resizable()
                      .frame(width: 20, height: 20)
                      .clipShape(RoundedRectangle(cornerRadius: 4))
                  Text("Stundenplan")
                      .font(.caption2)
                      .foregroundStyle(.secondary)
              }
              Spacer()
              if let lesson = relevantLesson {
                  Text(lesson.name)
                      .font(.headline)
                      .lineLimit(2)
                  Text("\(lesson.start) Uhr")
                      .font(.caption)
                      .foregroundStyle(.secondary)
              } else {
                  Text("Keine Stunden")
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
              }
          }
          .padding()
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  // MARK: - Medium View
  struct TimetableMediumView: View {
      let data: TimetableData?

      private var currentAndNext: [TimetableEntry] {
          guard let today = data?.today else { return [] }
          let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
          let nowMin = (now.hour ?? 0) * 60 + (now.minute ?? 0)
          return today.filter { entry in
              let endParts = entry.end.split(separator: ":").compactMap { Int($0) }
              let endMin = (endParts.first ?? 0) * 60 + (endParts.last ?? 0)
              return endMin > nowMin
          }.prefix(3).map { $0 }
      }

      var body: some View {
          VStack(alignment: .leading, spacing: 6) {
              HStack {
                  Image("AppIcon")
                      .resizable()
                      .frame(width: 16, height: 16)
                      .clipShape(RoundedRectangle(cornerRadius: 3))
                  Text("Stundenplan")
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                  Spacer()
              }
              if currentAndNext.isEmpty {
                  Spacer()
                  Text("Keine weiteren Stunden heute")
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
                  Spacer()
              } else {
                  ForEach(currentAndNext.indices, id: \.self) { i in
                      let lesson = currentAndNext[i]
                      HStack {
                          RoundedRectangle(cornerRadius: 2)
                              .fill(lesson.accentColor)
                              .frame(width: 3)
                          VStack(alignment: .leading, spacing: 0) {
                              Text(lesson.name)
                                  .font(.subheadline).bold()
                                  .lineLimit(1)
                              Text("\(lesson.start)–\(lesson.end)\(lesson.room.map { " · \($0)" } ?? "")")
                                  .font(.caption)
                                  .foregroundStyle(.secondary)
                          }
                          Spacer()
                      }
                  }
                  Spacer()
              }
          }
          .padding()
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  // MARK: - Large View
  struct TimetableLargeView: View {
      let data: TimetableData?

      var body: some View {
          VStack(alignment: .leading, spacing: 4) {
              HStack {
                  Image("AppIcon")
                      .resizable()
                      .frame(width: 18, height: 18)
                      .clipShape(RoundedRectangle(cornerRadius: 4))
                  Text("Stundenplan heute")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  Spacer()
              }
              Divider()
              if let today = data?.today, !today.isEmpty {
                  ForEach(today.indices, id: \.self) { i in
                      let lesson = today[i]
                      HStack(spacing: 8) {
                          Text(lesson.start)
                              .font(.caption2.monospacedDigit())
                              .foregroundStyle(.secondary)
                              .frame(width: 36, alignment: .trailing)
                          RoundedRectangle(cornerRadius: 2)
                              .fill(lesson.accentColor)
                              .frame(width: 3, height: 28)
                          VStack(alignment: .leading, spacing: 0) {
                              Text(lesson.name)
                                  .font(.subheadline).bold()
                                  .lineLimit(1)
                              if let room = lesson.room {
                                  Text(room)
                                      .font(.caption2)
                                      .foregroundStyle(.secondary)
                              }
                          }
                          Spacer()
                      }
                  }
              } else {
                  Spacer()
                  Text("Keine Stunden heute")
                      .foregroundStyle(.secondary)
                  Spacer()
              }
              Spacer()
          }
          .padding()
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  // MARK: - Lock Screen Views
  struct TimetableAccessoryCircularView: View {
      let data: TimetableData?
      var body: some View {
          let name = data?.currentLesson?.name ?? data?.today.first(where: { isUpcoming($0) })?.name ?? "–"
          let short = String(name.prefix(3))
          ZStack {
              AccessoryWidgetBackground()
              Text(short)
                  .font(.caption.bold())
                  .widgetAccentable()
          }
      }
  }

  struct TimetableAccessoryRectangularView: View {
      let data: TimetableData?
      var body: some View {
          let lesson = data?.currentLesson ?? data?.today.first(where: { isUpcoming($0) })
          if let l = lesson {
              VStack(alignment: .leading) {
                  Text(l.name).font(.headline).widgetAccentable()
                  Text("\(l.start) Uhr\(l.room.map { " · \($0)" } ?? "")").font(.caption)
              }
          } else {
              Text("Keine Stunden").font(.caption)
          }
      }
  }

  struct TimetableAccessoryInlineView: View {
      let data: TimetableData?
      var body: some View {
          let lesson = data?.currentLesson ?? data?.today.first(where: { isUpcoming($0) })
          if let l = lesson {
              Text("Jetzt: \(l.name)\(l.room.map { " \($0)" } ?? "")")
          } else {
              Text("Kein Unterricht")
          }
      }
  }

  // MARK: - Widget
  struct StundenplanWidget: Widget {
      let kind = "StundenplanWidget"

      var body: some WidgetConfiguration {
          StaticConfiguration(kind: kind, provider: TimetableProvider()) { entry in
              StundenplanWidgetView(entry: entry)
          }
          .configurationDisplayName("Stundenplan")
          .description("Zeigt deine heutigen Stunden.")
          .supportedFamilies(supportedFamilies)
      }

      private var supportedFamilies: [WidgetFamily] {
          var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
          if #available(iOSApplicationExtension 16.0, *) {
              families += [.accessoryCircular, .accessoryRectangular, .accessoryInline]
          }
          return families
      }
  }

  struct StundenplanWidgetView: View {
      let entry: TimetableTimelineEntry
      @Environment(\.widgetFamily) var family

      var body: some View {
          switch family {
          case .systemSmall:
              TimetableSmallView(data: entry.data)
          case .systemMedium:
              TimetableMediumView(data: entry.data)
          case .systemLarge:
              TimetableLargeView(data: entry.data)
          default:
              if #available(iOSApplicationExtension 16.0, *) {
                  switch family {
                  case .accessoryCircular:
                      TimetableAccessoryCircularView(data: entry.data)
                  case .accessoryRectangular:
                      TimetableAccessoryRectangularView(data: entry.data)
                  case .accessoryInline:
                      TimetableAccessoryInlineView(data: entry.data)
                  default:
                      EmptyView()
                  }
              }
          }
      }
  }

  // MARK: - Helpers
  private func isUpcoming(_ entry: TimetableEntry) -> Bool {
      let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
      let nowMin = (now.hour ?? 0) * 60 + (now.minute ?? 0)
      let parts = entry.start.split(separator: ":").compactMap { Int($0) }
      let startMin = (parts.first ?? 0) * 60 + (parts.last ?? 0)
      return startMin > nowMin
  }
  ```

- [ ] **Step 2: Build prüfen**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -20
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add ios/LanisWidgets/StundenplanWidget.swift
  git commit -m "feat(ios): implement StundenplanWidget (all sizes + lock screen)"
  ```

---

## Task 8: Swift — VertretungsWidget

**Files:**
- Create/Modify: `ios/LanisWidgets/VertretungsWidget.swift`

- [ ] **Step 1: VertretungsWidget implementieren**

  `ios/LanisWidgets/VertretungsWidget.swift`:
  ```swift
  import WidgetKit
  import SwiftUI

  struct SubstitutionTimelineEntry: TimelineEntry {
      let date: Date
      let data: SubstitutionData?
  }

  struct SubstitutionProvider: TimelineProvider {
      func placeholder(in context: Context) -> SubstitutionTimelineEntry {
          SubstitutionTimelineEntry(date: Date(), data: nil)
      }
      func getSnapshot(in context: Context, completion: @escaping (SubstitutionTimelineEntry) -> Void) {
          completion(SubstitutionTimelineEntry(date: Date(), data: WidgetDataReader.substitutions()))
      }
      func getTimeline(in context: Context, completion: @escaping (Timeline<SubstitutionTimelineEntry>) -> Void) {
          let entry = SubstitutionTimelineEntry(date: Date(), data: WidgetDataReader.substitutions())
          let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
          completion(Timeline(entries: [entry], policy: .after(next)))
      }
  }

  struct VertretungsSmallView: View {
      let data: SubstitutionData?
      var body: some View {
          VStack(alignment: .leading, spacing: 4) {
              HStack {
                  Image("AppIcon").resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
                  Text("Vertretung").font(.caption2).foregroundStyle(.secondary)
              }
              Spacer()
              let count = data?.entries.count ?? 0
              Text("\(count)").font(.system(size: 36, weight: .bold)).foregroundStyle(count > 0 ? .red : .secondary)
              Text(count == 1 ? "Vertretung" : "Vertretungen").font(.caption).foregroundStyle(.secondary)
              if let first = data?.entries.first {
                  Text("\(first.stunde). Std · \(first.art ?? "")").font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
              }
          }
          .padding()
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  struct VertretungsMediumView: View {
      let data: SubstitutionData?
      var body: some View {
          VStack(alignment: .leading, spacing: 6) {
              HStack {
                  Image("AppIcon").resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                  Text("Vertretungen").font(.caption2).foregroundStyle(.secondary)
                  Spacer()
                  if let date = data?.date { Text(date).font(.caption2).foregroundStyle(.tertiary) }
              }
              let entries = Array((data?.entries ?? []).prefix(3))
              if entries.isEmpty {
                  Spacer()
                  Text("Keine Vertretungen").font(.subheadline).foregroundStyle(.secondary)
                  Spacer()
              } else {
                  ForEach(entries.indices, id: \.self) { i in
                      let e = entries[i]
                      HStack(spacing: 6) {
                          Text("\(e.stunde).")
                              .font(.caption.monospacedDigit()).bold()
                              .frame(width: 20, alignment: .trailing)
                          Text(e.fach ?? "–").font(.subheadline).lineLimit(1)
                          Spacer()
                          Text(e.art ?? "").font(.caption).foregroundStyle(.secondary)
                      }
                  }
                  Spacer()
              }
          }
          .padding()
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  struct VertretungsLargeView: View {
      let data: SubstitutionData?
      var body: some View {
          VStack(alignment: .leading, spacing: 4) {
              HStack {
                  Image("AppIcon").resizable().frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 4))
                  Text("Vertretungen heute").font(.caption).foregroundStyle(.secondary)
                  Spacer()
                  if let date = data?.date { Text(date).font(.caption2).foregroundStyle(.tertiary) }
              }
              Divider()
              let entries = data?.entries ?? []
              if entries.isEmpty {
                  Spacer()
                  Text("Keine Vertretungen").foregroundStyle(.secondary)
                  Spacer()
              } else {
                  ForEach(entries.indices, id: \.self) { i in
                      let e = entries[i]
                      HStack(spacing: 8) {
                          Text("\(e.stunde).")
                              .font(.caption2.monospacedDigit()).bold()
                              .frame(width: 20, alignment: .trailing)
                          VStack(alignment: .leading, spacing: 0) {
                              Text(e.fach ?? "–").font(.subheadline).bold().lineLimit(1)
                              HStack(spacing: 4) {
                                  if let art = e.art { Text(art).font(.caption2).foregroundStyle(.red) }
                                  if let raum = e.raum { Text("→ \(raum)").font(.caption2).foregroundStyle(.secondary) }
                                  if let v = e.vertreter { Text(v).font(.caption2).foregroundStyle(.secondary) }
                              }
                          }
                          Spacer()
                      }
                  }
              }
              Spacer()
          }
          .padding()
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  struct VertretungsWidget: Widget {
      let kind = "VertretungsWidget"
      var body: some WidgetConfiguration {
          StaticConfiguration(kind: kind, provider: SubstitutionProvider()) { entry in
              VertretungsWidgetView(entry: entry)
          }
          .configurationDisplayName("Vertretungen")
          .description("Zeigt deine heutigen Vertretungen.")
          .supportedFamilies(supportedFamilies)
      }
      private var supportedFamilies: [WidgetFamily] {
          var f: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
          if #available(iOSApplicationExtension 16.0, *) { f += [.accessoryCircular, .accessoryRectangular, .accessoryInline] }
          return f
      }
  }

  struct VertretungsWidgetView: View {
      let entry: SubstitutionTimelineEntry
      @Environment(\.widgetFamily) var family
      var body: some View {
          switch family {
          case .systemSmall: VertretungsSmallView(data: entry.data)
          case .systemMedium: VertretungsMediumView(data: entry.data)
          case .systemLarge: VertretungsLargeView(data: entry.data)
          default:
              if #available(iOSApplicationExtension 16.0, *) {
                  let count = entry.data?.entries.count ?? 0
                  switch family {
                  case .accessoryCircular:
                      ZStack {
                          AccessoryWidgetBackground()
                          Text("\(count)").font(.headline.bold()).widgetAccentable()
                      }
                  case .accessoryRectangular:
                      VStack(alignment: .leading) {
                          if let first = entry.data?.entries.first {
                              Text("\(first.stunde). Std · \(first.art ?? "")").font(.headline).widgetAccentable()
                              Text(first.fach ?? "–").font(.caption)
                          } else {
                              Text("Keine Vertretungen").font(.caption)
                          }
                      }
                  case .accessoryInline:
                      Text(count > 0 ? "\(count) Vertretung\(count == 1 ? "" : "en") heute" : "Keine Vertretungen")
                  default: EmptyView()
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build prüfen**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -20
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add ios/LanisWidgets/VertretungsWidget.swift
  git commit -m "feat(ios): implement VertretungsWidget (all sizes + lock screen)"
  ```

---

## Task 9: Swift — KalenderWidget

**Files:**
- Create: `ios/LanisWidgets/KalenderWidget.swift`

- [ ] **Step 1: KalenderWidget implementieren**

  `ios/LanisWidgets/KalenderWidget.swift`:
  ```swift
  import WidgetKit
  import SwiftUI

  struct CalendarTimelineEntry: TimelineEntry {
      let date: Date
      let data: CalendarData?
  }

  struct CalendarProvider: TimelineProvider {
      func placeholder(in context: Context) -> CalendarTimelineEntry { CalendarTimelineEntry(date: Date(), data: nil) }
      func getSnapshot(in context: Context, completion: @escaping (CalendarTimelineEntry) -> Void) {
          completion(CalendarTimelineEntry(date: Date(), data: WidgetDataReader.calendar()))
      }
      func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarTimelineEntry>) -> Void) {
          let entry = CalendarTimelineEntry(date: Date(), data: WidgetDataReader.calendar())
          let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
          completion(Timeline(entries: [entry], policy: .after(next)))
      }
  }

  private func formatEventDate(_ date: Date?) -> String {
      guard let date else { return "" }
      let cal = Calendar.current
      if cal.isDateInToday(date) { return "Heute" }
      if cal.isDateInTomorrow(date) { return "Morgen" }
      return date.formatted(.dateTime.day().month())
  }

  struct KalenderSmallView: View {
      let data: CalendarData?
      var body: some View {
          VStack(alignment: .leading, spacing: 4) {
              HStack {
                  Image("AppIcon").resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
                  Text("Kalender").font(.caption2).foregroundStyle(.secondary)
              }
              Spacer()
              if let event = data?.events.first {
                  Text(event.title).font(.subheadline).bold().lineLimit(2)
                  Text(formatEventDate(event.startDate)).font(.caption).foregroundStyle(.secondary)
              } else {
                  Text("Keine Ereignisse").font(.subheadline).foregroundStyle(.secondary)
              }
          }
          .padding()
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  struct KalenderMediumView: View {
      let data: CalendarData?
      var body: some View {
          VStack(alignment: .leading, spacing: 6) {
              HStack {
                  Image("AppIcon").resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                  Text("Kalender").font(.caption2).foregroundStyle(.secondary)
                  Spacer()
              }
              let events = Array((data?.events ?? []).prefix(3))
              if events.isEmpty {
                  Spacer()
                  Text("Keine bevorstehenden Ereignisse").font(.subheadline).foregroundStyle(.secondary)
                  Spacer()
              } else {
                  ForEach(events.indices, id: \.self) { i in
                      let e = events[i]
                      HStack(spacing: 8) {
                          RoundedRectangle(cornerRadius: 2).fill(e.accentColor).frame(width: 3)
                          VStack(alignment: .leading, spacing: 0) {
                              Text(e.title).font(.subheadline).bold().lineLimit(1)
                              Text(formatEventDate(e.startDate)).font(.caption).foregroundStyle(.secondary)
                          }
                          Spacer()
                      }
                  }
                  Spacer()
              }
          }
          .padding()
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  struct KalenderLargeView: View {
      let data: CalendarData?
      var body: some View {
          VStack(alignment: .leading, spacing: 4) {
              HStack {
                  Image("AppIcon").resizable().frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 4))
                  Text("Kalender").font(.caption).foregroundStyle(.secondary)
                  Spacer()
              }
              Divider()
              let events = Array((data?.events ?? []).prefix(7))
              if events.isEmpty {
                  Spacer()
                  Text("Keine bevorstehenden Ereignisse").foregroundStyle(.secondary)
                  Spacer()
              } else {
                  ForEach(events.indices, id: \.self) { i in
                      let e = events[i]
                      HStack(spacing: 8) {
                          RoundedRectangle(cornerRadius: 2).fill(e.accentColor).frame(width: 3, height: 28)
                          VStack(alignment: .leading, spacing: 0) {
                              Text(e.title).font(.subheadline).bold().lineLimit(1)
                              Text(formatEventDate(e.startDate)).font(.caption2).foregroundStyle(.secondary)
                          }
                          Spacer()
                      }
                  }
              }
              Spacer()
          }
          .padding()
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  struct KalenderWidget: Widget {
      let kind = "KalenderWidget"
      var body: some WidgetConfiguration {
          StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
              KalenderWidgetView(entry: entry)
          }
          .configurationDisplayName("Kalender")
          .description("Zeigt bevorstehende Schulereignisse.")
          .supportedFamilies({
              var f: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
              if #available(iOSApplicationExtension 16.0, *) { f += [.accessoryCircular, .accessoryRectangular, .accessoryInline] }
              return f
          }())
      }
  }

  struct KalenderWidgetView: View {
      let entry: CalendarTimelineEntry
      @Environment(\.widgetFamily) var family
      var body: some View {
          switch family {
          case .systemSmall: KalenderSmallView(data: entry.data)
          case .systemMedium: KalenderMediumView(data: entry.data)
          case .systemLarge: KalenderLargeView(data: entry.data)
          default:
              if #available(iOSApplicationExtension 16.0, *) {
                  let next = entry.data?.events.first
                  switch family {
                  case .accessoryCircular:
                      ZStack {
                          AccessoryWidgetBackground()
                          if let d = next?.startDate {
                              let days = Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0
                              Text(days == 0 ? "Heute" : "+\(days)").font(.caption2.bold()).widgetAccentable()
                          } else {
                              Image(systemName: "calendar").widgetAccentable()
                          }
                      }
                  case .accessoryRectangular:
                      VStack(alignment: .leading) {
                          if let e = next {
                              Text(e.title).font(.headline).widgetAccentable().lineLimit(1)
                              Text(formatEventDate(e.startDate)).font(.caption)
                          } else {
                              Text("Kein Ereignis").font(.caption)
                          }
                      }
                  case .accessoryInline:
                      if let e = next { Text("\(formatEventDate(e.startDate)): \(e.title)") }
                      else { Text("Keine Ereignisse") }
                  default: EmptyView()
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build prüfen**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -20
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add ios/LanisWidgets/KalenderWidget.swift
  git commit -m "feat(ios): implement KalenderWidget (all sizes + lock screen)"
  ```

---

## Task 10: Swift — NachrichtenWidget

**Files:**
- Create: `ios/LanisWidgets/NachrichtenWidget.swift`

- [ ] **Step 1: NachrichtenWidget implementieren**

  `ios/LanisWidgets/NachrichtenWidget.swift`:
  ```swift
  import WidgetKit
  import SwiftUI

  struct ConversationsTimelineEntry: TimelineEntry {
      let date: Date
      let data: ConversationsData?
  }

  struct ConversationsProvider: TimelineProvider {
      func placeholder(in context: Context) -> ConversationsTimelineEntry { ConversationsTimelineEntry(date: Date(), data: nil) }
      func getSnapshot(in context: Context, completion: @escaping (ConversationsTimelineEntry) -> Void) {
          completion(ConversationsTimelineEntry(date: Date(), data: WidgetDataReader.conversations()))
      }
      func getTimeline(in context: Context, completion: @escaping (Timeline<ConversationsTimelineEntry>) -> Void) {
          let entry = ConversationsTimelineEntry(date: Date(), data: WidgetDataReader.conversations())
          let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
          completion(Timeline(entries: [entry], policy: .after(next)))
      }
  }

  struct NachrichtenSmallView: View {
      let data: ConversationsData?
      var body: some View {
          VStack(alignment: .leading, spacing: 4) {
              HStack {
                  Image("AppIcon").resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
                  Text("Nachrichten").font(.caption2).foregroundStyle(.secondary)
              }
              Spacer()
              let count = data?.unreadCount ?? 0
              Text("\(count)").font(.system(size: 36, weight: .bold)).foregroundStyle(count > 0 ? .accentColor : .secondary)
              Text("Ungelesen").font(.caption).foregroundStyle(.secondary)
          }
          .padding()
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  struct NachrichtenMediumView: View {
      let data: ConversationsData?
      var body: some View {
          VStack(alignment: .leading, spacing: 6) {
              HStack {
                  Image("AppIcon").resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                  Text("Nachrichten").font(.caption2).foregroundStyle(.secondary)
                  Spacer()
                  let count = data?.unreadCount ?? 0
                  if count > 0 {
                      Text("\(count) ungelesen")
                          .font(.caption2)
                          .foregroundStyle(.white)
                          .padding(.horizontal, 6).padding(.vertical, 2)
                          .background(Color.accentColor)
                          .clipShape(Capsule())
                  }
              }
              let msgs = Array((data?.latest ?? []).prefix(2))
              if msgs.isEmpty {
                  Spacer()
                  Text("Keine Nachrichten").font(.subheadline).foregroundStyle(.secondary)
                  Spacer()
              } else {
                  ForEach(msgs.indices, id: \.self) { i in
                      let m = msgs[i]
                      HStack(spacing: 6) {
                          Circle().fill(m.isUnread ? Color.accentColor : .clear).frame(width: 6, height: 6)
                          VStack(alignment: .leading, spacing: 0) {
                              Text(m.sender).font(.caption.bold()).lineLimit(1)
                              Text(m.subject).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                          }
                          Spacer()
                      }
                  }
                  Spacer()
              }
          }
          .padding()
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  struct NachrichtenLargeView: View {
      let data: ConversationsData?
      var body: some View {
          VStack(alignment: .leading, spacing: 4) {
              HStack {
                  Image("AppIcon").resizable().frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 4))
                  Text("Nachrichten").font(.caption).foregroundStyle(.secondary)
                  Spacer()
                  let count = data?.unreadCount ?? 0
                  if count > 0 {
                      Text("\(count) ungelesen").font(.caption2).foregroundStyle(.accentColor)
                  }
              }
              Divider()
              let msgs = data?.latest ?? []
              if msgs.isEmpty {
                  Spacer()
                  Text("Keine Nachrichten").foregroundStyle(.secondary)
                  Spacer()
              } else {
                  ForEach(msgs.indices, id: \.self) { i in
                      let m = msgs[i]
                      HStack(spacing: 8) {
                          Circle().fill(m.isUnread ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width: 8, height: 8)
                          VStack(alignment: .leading, spacing: 0) {
                              Text(m.sender).font(.subheadline).bold().lineLimit(1)
                              Text(m.subject).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                          }
                          Spacer()
                      }
                  }
              }
              Spacer()
          }
          .padding()
          .containerBackground(.fill.tertiary, for: .widget)
      }
  }

  struct NachrichtenWidget: Widget {
      let kind = "NachrichtenWidget"
      var body: some WidgetConfiguration {
          StaticConfiguration(kind: kind, provider: ConversationsProvider()) { entry in
              NachrichtenWidgetView(entry: entry)
          }
          .configurationDisplayName("Nachrichten")
          .description("Zeigt ungelesene Nachrichten.")
          .supportedFamilies({
              var f: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
              if #available(iOSApplicationExtension 16.0, *) { f += [.accessoryCircular, .accessoryRectangular, .accessoryInline] }
              return f
          }())
      }
  }

  struct NachrichtenWidgetView: View {
      let entry: ConversationsTimelineEntry
      @Environment(\.widgetFamily) var family
      var body: some View {
          switch family {
          case .systemSmall: NachrichtenSmallView(data: entry.data)
          case .systemMedium: NachrichtenMediumView(data: entry.data)
          case .systemLarge: NachrichtenLargeView(data: entry.data)
          default:
              if #available(iOSApplicationExtension 16.0, *) {
                  let count = entry.data?.unreadCount ?? 0
                  switch family {
                  case .accessoryCircular:
                      ZStack {
                          AccessoryWidgetBackground()
                          Text("\(count)").font(.headline.bold()).widgetAccentable()
                      }
                  case .accessoryRectangular:
                      VStack(alignment: .leading) {
                          if let first = entry.data?.latest.first {
                              Text(first.sender).font(.headline).widgetAccentable().lineLimit(1)
                              Text(first.subject).font(.caption).lineLimit(1)
                          } else {
                              Text("Keine Nachrichten").font(.caption)
                          }
                      }
                  case .accessoryInline:
                      Text(count > 0 ? "\(count) ungelesene Nachricht\(count == 1 ? "" : "en")" : "Keine neuen Nachrichten")
                  default: EmptyView()
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build prüfen**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -20
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add ios/LanisWidgets/NachrichtenWidget.swift
  git commit -m "feat(ios): implement NachrichtenWidget (all sizes + lock screen)"
  ```

---

## Task 11: Swift — Stunden Live Activity View

**Files:**
- Create: `ios/LanisWidgets/StundenLiveActivity.swift`

- [ ] **Step 1: StundenLiveActivity View implementieren**

  `ios/LanisWidgets/StundenLiveActivity.swift`:
  ```swift
  import ActivityKit
  import WidgetKit
  import SwiftUI

  @available(iOSApplicationExtension 16.2, *)
  struct StundenLiveActivityView: View {
      let attributes: LessonActivityAttributes
      let state: LessonActivityAttributes.ContentState

      var body: some View {
          VStack(spacing: 8) {
              HStack {
                  VStack(alignment: .leading, spacing: 2) {
                      HStack(spacing: 6) {
                          Image("AppIcon").resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                          Text(attributes.lessonName).font(.headline).bold()
                      }
                      HStack(spacing: 8) {
                          if let room = attributes.room {
                              Label(room, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                          }
                          if let teacher = attributes.teacher {
                              Label(teacher, systemImage: "person").font(.caption).foregroundStyle(.secondary)
                          }
                      }
                  }
                  Spacer()
                  Text(timerInterval: Date()...state.endTime, countsDown: true)
                      .font(.title2.monospacedDigit().bold())
                      .foregroundStyle(.accentColor)
                      .frame(width: 70, alignment: .trailing)
              }

              // Fortschrittsbalken
              GeometryReader { geo in
                  ZStack(alignment: .leading) {
                      RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2)).frame(height: 4)
                      RoundedRectangle(cornerRadius: 3).fill(Color.accentColor).frame(width: geo.size.width * progressFraction, height: 4)
                  }
              }.frame(height: 4)

              if let next = state.nextLessonName {
                  HStack {
                      Text("Danach: \(next)\(state.nextLessonStart.map { " um \($0)" } ?? "")").font(.caption).foregroundStyle(.secondary)
                      Spacer()
                  }
              }
          }
          .padding()
      }

      private var progressFraction: CGFloat {
          let total = state.endTime.timeIntervalSinceNow + 45 * 60
          let elapsed = total - state.endTime.timeIntervalSinceNow
          return min(max(CGFloat(elapsed / total), 0), 1)
      }
  }

  @available(iOSApplicationExtension 16.2, *)
  struct StundenLiveActivityWidget: Widget {
      var body: some WidgetConfiguration {
          ActivityConfiguration(for: LessonActivityAttributes.self) { context in
              StundenLiveActivityView(attributes: context.attributes, state: context.state)
                  .containerBackground(.fill.tertiary, for: .widget)
          } dynamicIsland: { context in
              DynamicIsland {
                  DynamicIslandExpandedRegion(.leading) {
                      HStack {
                          Image("AppIcon").resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 4))
                          Text(context.attributes.lessonName).font(.headline)
                      }
                  }
                  DynamicIslandExpandedRegion(.trailing) {
                      Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                          .font(.headline.monospacedDigit()).foregroundStyle(.accentColor)
                  }
                  DynamicIslandExpandedRegion(.bottom) {
                      HStack {
                          if let room = context.attributes.room {
                              Label(room, systemImage: "mappin").font(.caption)
                          }
                          if let teacher = context.attributes.teacher {
                              Label(teacher, systemImage: "person").font(.caption)
                          }
                          Spacer()
                          if let next = context.state.nextLessonName {
                              Text("→ \(next)").font(.caption).foregroundStyle(.secondary)
                          }
                      }
                  }
              } compactLeading: {
                  Text(String(context.attributes.lessonName.prefix(3))).font(.caption.bold())
              } compactTrailing: {
                  Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                      .font(.caption2.monospacedDigit())
                      .frame(width: 40)
              } minimal: {
                  Text(String(context.attributes.lessonName.prefix(2))).font(.caption2.bold())
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build prüfen**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -20
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add ios/LanisWidgets/StundenLiveActivity.swift
  git commit -m "feat(ios): implement Stunden Live Activity with Dynamic Island"
  ```

---

## Task 12: Swift — Vertretungs Live Activity View

**Files:**
- Create: `ios/LanisWidgets/VertretungsLiveActivity.swift`

- [ ] **Step 1: VertretungsLiveActivity View implementieren**

  `ios/LanisWidgets/VertretungsLiveActivity.swift`:
  ```swift
  import ActivityKit
  import WidgetKit
  import SwiftUI

  @available(iOSApplicationExtension 16.2, *)
  struct VertretungsLiveActivityView: View {
      let attributes: SubstitutionActivityAttributes
      let state: SubstitutionActivityAttributes.ContentState

      var body: some View {
          VStack(alignment: .leading, spacing: 8) {
              HStack {
                  Image("AppIcon").resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                  Text("\(state.count) neue\(state.count == 1 ? " Vertretung" : " Vertretungen")")
                      .font(.headline).bold()
                  Spacer()
                  Text(attributes.date).font(.caption).foregroundStyle(.secondary)
              }
              ForEach(state.entries.prefix(3).indices, id: \.self) { i in
                  let e = state.entries[i]
                  HStack(spacing: 6) {
                      Text("\(e.stunde).").font(.caption.bold().monospacedDigit()).frame(width: 20, alignment: .trailing)
                      Text(e.fach ?? "–").font(.subheadline).lineLimit(1)
                      Spacer()
                      Text(e.art ?? "").font(.caption).foregroundStyle(.red)
                  }
              }
          }
          .padding()
      }
  }

  @available(iOSApplicationExtension 16.2, *)
  struct VertretungsLiveActivityWidget: Widget {
      var body: some WidgetConfiguration {
          ActivityConfiguration(for: SubstitutionActivityAttributes.self) { context in
              VertretungsLiveActivityView(attributes: context.attributes, state: context.state)
                  .containerBackground(.fill.tertiary, for: .widget)
          } dynamicIsland: { context in
              DynamicIsland {
                  DynamicIslandExpandedRegion(.leading) {
                      HStack {
                          Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                          Text("Vertretungen").font(.headline)
                      }
                  }
                  DynamicIslandExpandedRegion(.trailing) {
                      Text("\(context.state.count)").font(.title2.bold()).foregroundStyle(.red)
                  }
                  DynamicIslandExpandedRegion(.bottom) {
                      VStack(alignment: .leading, spacing: 2) {
                          ForEach(context.state.entries.prefix(2).indices, id: \.self) { i in
                              let e = context.state.entries[i]
                              HStack {
                                  Text("\(e.stunde). \(e.fach ?? "–")").font(.caption)
                                  Spacer()
                                  Text(e.art ?? "").font(.caption).foregroundStyle(.red)
                              }
                          }
                      }
                  }
              } compactLeading: {
                  Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow).font(.caption)
              } compactTrailing: {
                  Text("\(context.state.count)").font(.caption.bold()).foregroundStyle(.red)
              } minimal: {
                  Text("\(context.state.count)").font(.caption2.bold()).foregroundStyle(.red)
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build prüfen**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -20
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add ios/LanisWidgets/VertretungsLiveActivity.swift
  git commit -m "feat(ios): implement Vertretungs Live Activity with Dynamic Island"
  ```

---

## Task 13: Abschluss — Vollständiger Build & manuelle Tests

- [ ] **Step 1: Vollständiger Flutter Build**

  ```bash
  flutter build ios --no-codesign 2>&1 | tail -40
  ```
  Erwartet: Build succeeded

- [ ] **Step 2: Dart-Analyse**

  ```bash
  dart analyze lib/ 2>&1 | grep -E "error:|warning:" | head -20
  ```
  Erwartet: Keine Errors in den neuen Dateien

- [ ] **Step 3: Manuelle Checkliste (auf Device/Simulator)**

  - App starten → im Debugger prüfen: `WidgetDataService.instance.updateAll()` wird aufgerufen (kein Exception-Log)
  - Widget aus Widgetgalerie hinzufügen: `StundenplanWidget`, `VertretungsWidget`, `KalenderWidget`, `NachrichtenWidget` erscheinen in der Galerie
  - Jede Widget-Größe prüfen: small, medium, large, accessory (Lock Screen)
  - Widget zeigt „Keine Daten" / sinnvollen Placeholder wenn App noch nicht eingeloggt war
  - Nach Login zeigen Widgets Daten an
  - Live Activity: `WidgetDataService.instance.startLessonActivity(...)` über ein Test-Button auslösen → Dynamic Island erscheint

- [ ] **Step 4: Final Commit**

  ```bash
  git add .
  git commit -m "feat(ios): complete iOS widgets and live activities implementation"
  ```

---

## Bekannte Einschränkungen

- **App-Icon im Widget:** `Image("AppIcon")` funktioniert nur, wenn das App-Icon-Asset auch in der Widget Extension verfügbar ist. Im Xcode Asset Catalog das Icon-Asset der Widget Extension Target-Membership hinzufügen.
- **Deployment Target Konflikt:** Podfile bleibt auf iOS 13. Das Widget Extension Target braucht iOS 14 als Deployment Target — dies wird direkt in Xcode im Target Build Settings gesetzt, nicht im Podfile.
- **containerBackground:** Erst ab iOS 17 verfügbar. Für iOS 14–16 Fallback auf `.background(Color(UIColor.systemBackground))` falls der Build fehlschlägt.
- **Simulator Live Activities:** ActivityKit funktioniert nicht im Simulator — echtes Device notwendig für Task 11/12 manuelle Tests.
