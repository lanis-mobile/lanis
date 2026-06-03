# Design: Sortierung Unterricht, Kalenderfilter, Anwesenheits-Toggle

**Issues:** #406, #478, #479  
**Date:** 2026-06-03

---

## #406 — Sortieroptionen für Unterricht (Schüler-Ansicht)

### Ziel
Nutzer können die Reihenfolge der Kurse in der Schüler-Unterrichtsansicht selbst bestimmen.

### Sortieroptionen
- `date_desc` — Nach Datum absteigend (neuester Eintrag zuerst) — bisheriges Verhalten
- `date_asc` — Nach Datum aufsteigend (ältester Eintrag zuerst)
- `alpha` — Alphabetisch nach Kursname (A–Z)
- `teacher` — Alphabetisch nach erstem Lehrernamen

### UI
- Horizontal scrollende `FilterChip`-Reihe in der AppBar (als `bottom:`-Widget).
- Immer genau ein Chip aktiv (Single-Select).
- Persistiert als `settingsDefaults`-Key `'sortOption'` mit Default `'date_desc'`.

### Architektur
- `lessonsDefinition.settingsDefaults`: `{'showHomework': false, 'sortOption': 'date_desc'}` hinzufügen.
- In `_LessonsStudentViewState`: Neue Hilfsmethode `_sortLessons(Lessons lessons, String sortOption) → Lessons` extrahiert die bestehende Sortierlogik und erweitert sie.
- AppBar bekommt `bottom: PreferredSize(...)` mit den 4 `FilterChip`s. Nur sichtbar wenn `settings['showHomework'] != true`.

### Betroffene Dateien
- `lib/applets/lessons/definition.dart`
- `lib/applets/lessons/student/lessons_student_view.dart`

---

## #478 — Kalenderfilter nach Kategorie

### Ziel
Nutzer können Kalendereinträge nach Kategorie (z.B. „Klausuren", „Ferien") filtern.

### Verhalten
- Unter der AppBar erscheint eine horizontal scrollende `FilterChip`-Reihe — nur wenn mindestens eine Kategorie in den geladenen Events vorhanden ist.
- Erster Chip: „Alle" — deaktiviert alle Filter, zeigt alle Events.
- Pro Kategorie ein Chip mit farbigem Avatar (Kategorie-Farbe) und Kategoriename.
- Mehrfachauswahl möglich: mehrere Kategorien gleichzeitig aktiv zeigt Events aus beiden.
- Events ohne Kategorie (`category == null`) werden immer angezeigt, außer wenn mindestens ein Kategorie-Chip aktiv ist (dann werden sie ausgeblendet).
- Filter ist rein clientseitig — kein neuer API-Call.
- Aktive Filter werden **nicht** persistiert (vergessen beim Verlassen der Ansicht).

### Architektur
- In `CalendarView`: State-Variable `Set<int> _activeFilterIds = {}` (leer = alle anzeigen).
- Filtermethode: `List<CalendarEvent> _applyFilter(List<CalendarEvent> events)`.
- `calendarDefinition.settingsDefaults` bleibt unverändert.

### Betroffene Dateien
- `lib/applets/calendar/calendar_view.dart`

---

## #479 — Anwesenheits-Tabellenansicht (Toggle)

### Ziel
Nutzer können zwischen der bisherigen Card-Ansicht und einer kompakten Tabellenansicht wechseln.

### Card-Ansicht (bestehend)
Unverändert — eine Card pro Kurs mit Key-Value-Rows.

### Tabellenansicht (neu)
- Spalten: alle vorkommenden Attendance-Keys (z.B. „anwesend", „fehlend", „verspätet") — alphabetisch sortiert, aus der Union aller Lesson-Attendances.
- Zeilen: je eine Zeile pro Kurs (Kursname als erste Spalte), plus eine fett hervorgehobene Summenzeile am Anfang.
- Horizontal scrollbar wenn Spalten zu viele für den Screen.
- Fehlende Werte in einer Zelle: „—".

### Toggle
- Icon-Button in der AppBar von `AttendancesScreen`: `Icons.table_chart` / `Icons.view_agenda`.
- Zustand wird als `'attendanceView': 'cards'` Setting in `lessonsDefinition.settingsDefaults` persistiert.
- `AttendancesScreen` erhält `settings` und `updateSetting` aus dem aufrufenden View.

### Architektur
- Neues Widget `AttendanceTableView` in `attendances.dart`.
- `AttendancesScreen` bekommt zwei neue Parameter: `Map<String, dynamic> settings` und `Future<void> Function(String, dynamic) updateSetting`.
- `LessonsStudentView` übergibt diese beim `Navigator.push`.
- `lessonsDefinition.settingsDefaults`: `{'showHomework': false, 'sortOption': 'date_desc', 'attendanceView': 'cards'}`.

### Betroffene Dateien
- `lib/applets/lessons/definition.dart`
- `lib/applets/lessons/student/attendances.dart`
- `lib/applets/lessons/student/lessons_student_view.dart`
