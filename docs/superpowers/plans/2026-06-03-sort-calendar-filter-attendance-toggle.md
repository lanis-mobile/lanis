# Sort / Calendar Filter / Attendance Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement three independent UI features: sort options for the student lessons view (#406), category filter chips in the calendar (#478), and a card/table toggle for the attendance screen (#479).

**Architecture:** Each feature is self-contained. #406 and #479 both touch `lib/applets/lessons/` — definition, view, and attendances. #478 touches only `lib/applets/calendar/calendar_view.dart`. All three persist state via the existing `updateSetting` / `settingsDefaults` pattern from `CombinedAppletBuilder`. No new files needed.

**Tech Stack:** Flutter/Dart, existing `CombinedAppletBuilder` settings pattern, `FilterChip`, `SingleChildScrollView` (horizontal), `DataTable`.

---

## File Map

| File | Change |
|------|--------|
| `lib/applets/lessons/definition.dart` | Add `'sortOption': 'date_desc'` and `'attendanceView': 'cards'` to `settingsDefaults` |
| `lib/applets/lessons/student/lessons_student_view.dart` | Add `_sortLessons()`, FilterChip row in AppBar, pass settings to `AttendancesScreen` |
| `lib/applets/lessons/student/attendances.dart` | Convert to `StatefulWidget`, add `AttendanceTableView`, toggle icon in AppBar |
| `lib/applets/calendar/calendar_view.dart` | Add `_activeFilterIds`, `_applyFilter()`, FilterChip row below search bar |

---

## Task 1: Add new settingsDefaults (#406 + #479)

**Files:**
- Modify: `lib/applets/lessons/definition.dart`

- [ ] **Update settingsDefaults**

Replace:
```dart
settingsDefaults: {'showHomework': false},
```
With:
```dart
settingsDefaults: {
  'showHomework': false,
  'sortOption': 'date_desc',
  'attendanceView': 'cards',
},
```

- [ ] **Verify analyzer passes**

```bash
flutter analyze lib/applets/lessons/definition.dart
```
Expected: `No issues found!`

- [ ] **Commit**

```bash
git add lib/applets/lessons/definition.dart
git commit -m "feat(lessons): add sortOption and attendanceView settingsDefaults"
```

---

## Task 2: Sort options in student lessons view (#406)

**Files:**
- Modify: `lib/applets/lessons/student/lessons_student_view.dart`

The builder in `_LessonsStudentViewState.build` already calls `lessons.sort(...)` for homework mode. We extract all sorting into one helper and add a chip row.

- [ ] **Add `_sortLessons` helper method** to `_LessonsStudentViewState` (place above `build`):

```dart
Lessons _sortLessons(Lessons lessons, String sortOption) {
  final sorted = List<Lesson>.from(lessons);
  switch (sortOption) {
    case 'date_asc':
      sorted.sort((a, b) {
        if (a.currentEntry?.topicDate == null) return 1;
        if (b.currentEntry?.topicDate == null) return -1;
        return a.currentEntry!.topicDate!.compareTo(b.currentEntry!.topicDate!);
      });
    case 'alpha':
      sorted.sort((a, b) => a.name.compareTo(b.name));
    case 'teacher':
      sorted.sort((a, b) {
        final aT = a.teachers.firstOrNull?.teacher ?? '';
        final bT = b.teachers.firstOrNull?.teacher ?? '';
        return aT.compareTo(bT);
      });
    case 'date_desc':
    default:
      sorted.sort((a, b) {
        if (a.currentEntry?.topicDate == null) return 1;
        if (b.currentEntry?.topicDate == null) return -1;
        return b.currentEntry!.topicDate!.compareTo(a.currentEntry!.topicDate!);
      });
  }
  return sorted;
}
```

- [ ] **Replace the existing sort block and add chip row**

In the `builder:` callback of `CombinedAppletBuilder`, find:

```dart
} else {
  attendanceLessons = lessons
      .where((element) => element.attendances != null)
      .toList();
}
```

Replace with:

```dart
} else {
  final sortOption = settings['sortOption'] as String? ?? 'date_desc';
  lessons = _sortLessons(lessons, sortOption);
  attendanceLessons = lessons
      .where((element) => element.attendances != null)
      .toList();
}
```

- [ ] **Add chip row widget** — add this private method to `_LessonsStudentViewState`:

```dart
Widget _sortChips(
  Map<String, dynamic> settings,
  Future<void> Function(String, dynamic) updateSetting,
) {
  const options = [
    ('date_desc', 'Datum ↓'),
    ('date_asc', 'Datum ↑'),
    ('alpha', 'A–Z'),
    ('teacher', 'Lehrer'),
  ];
  final current = settings['sortOption'] as String? ?? 'date_desc';
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: options.map((opt) {
        final (value, label) = opt;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text(label),
            selected: current == value,
            onSelected: (_) => updateSetting('sortOption', value),
          ),
        );
      }).toList(),
    ),
  );
}
```

- [ ] **Wire chip row into AppBar**

Find the `AppBar` inside the returned `Scaffold` in the builder callback. It currently has only `body:`. Replace the `Scaffold` return inside the builder with:

```dart
return Scaffold(
  appBar: settings['showHomework'] != true
      ? PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 52),
          child: AppBar(
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: _sortChips(settings, updateSetting),
            ),
          ),
        )
      : null,
  body: RefreshIndicator(
    // ... rest unchanged
```

> Note: the outer `Scaffold` (with the drawer `AppBar`) stays untouched — only the inner `Scaffold` returned from the builder gets the sort chips AppBar bottom.

- [ ] **Verify**

```bash
flutter analyze lib/applets/lessons/student/lessons_student_view.dart
```
Expected: `No issues found!`

- [ ] **Commit**

```bash
git add lib/applets/lessons/student/lessons_student_view.dart
git commit -m "feat(lessons): add sort option chips to student lessons view (#406)"
```

---

## Task 3: Attendance screen toggle (#479)

**Files:**
- Modify: `lib/applets/lessons/student/attendances.dart`
- Modify: `lib/applets/lessons/student/lessons_student_view.dart`

### Part A — Upgrade `AttendancesScreen` to StatefulWidget and add table view

- [ ] **Replace the entire `attendances.dart` content** with:

```dart
import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

import '../../../models/lessons.dart';

class AttendancesScreen extends StatefulWidget {
  const AttendancesScreen({
    super.key,
    required this.lessons,
    required this.settings,
    required this.updateSetting,
  });

  final Lessons lessons;
  final Map<String, dynamic> settings;
  final Future<void> Function(String, dynamic) updateSetting;

  @override
  State<AttendancesScreen> createState() => _AttendancesScreenState();
}

class _AttendancesScreenState extends State<AttendancesScreen> {
  bool get _isTableView =>
      (widget.settings['attendanceView'] as String?) == 'table';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).attendances),
        actions: [
          IconButton(
            icon: Icon(_isTableView ? Icons.view_agenda : Icons.table_chart),
            tooltip: _isTableView ? 'Kartenansicht' : 'Tabellenansicht',
            onPressed: () async {
              await widget.updateSetting(
                'attendanceView',
                _isTableView ? 'cards' : 'table',
              );
              setState(() {});
            },
          ),
        ],
      ),
      body: _isTableView
          ? AttendanceTableView(lessons: widget.lessons)
          : _cardListView(context),
    );
  }

  Widget _cardListView(BuildContext context) {
    return ListView.builder(
      itemCount: widget.lessons.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              AttendanceCard(
                title: AppLocalizations.of(context).allAttendances,
                teachers: [],
                attendances: getCombinedAttendances(widget.lessons),
              ),
              const Divider(),
            ],
          );
        }
        final lesson = widget.lessons[index - 1];
        return AttendanceCard(
          title: lesson.name,
          teachers: lesson.teachers,
          attendances: lesson.attendances!,
        );
      },
    );
  }
}

class AttendanceTableView extends StatelessWidget {
  const AttendanceTableView({super.key, required this.lessons});

  final Lessons lessons;

  @override
  Widget build(BuildContext context) {
    // Collect all unique keys across all lessons, sorted alphabetically.
    final allKeys = lessons
        .expand((l) => l.attendances?.keys ?? const Iterable.empty())
        .toSet()
        .toList()
      ..sort();

    if (allKeys.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).noEntries,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    final combined = getCombinedAttendances(lessons);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.secondaryContainer,
          ),
          columns: [
            const DataColumn(label: Text('Kurs')),
            ...allKeys.map((k) => DataColumn(label: Text(k))),
          ],
          rows: [
            // Summary row at top
            DataRow(
              color: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.primaryContainer,
              ),
              cells: [
                DataCell(
                  Text(
                    AppLocalizations.of(context).allAttendances,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...allKeys.map(
                  (k) => DataCell(
                    Text(
                      combined[k] ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            // One row per lesson
            ...lessons.map(
              (lesson) => DataRow(
                cells: [
                  DataCell(
                    Text(
                      lesson.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...allKeys.map(
                    (k) => DataCell(Text(lesson.attendances?[k] ?? '—')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceCard extends StatelessWidget {
  final String title;
  final List<LessonTeacher> teachers;
  final Map<String, String> attendances;
  const AttendanceCard({
    super.key,
    required this.attendances,
    required this.title,
    required this.teachers,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: teachers.isEmpty ? 8 : null,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (teachers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(teachers.map((e) => e.teacherKuerzel).join(', ')),
                    const SizedBox(width: 4),
                    Icon(
                      teachers.length > 1 ? Icons.people : Icons.person,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
            ...attendances.entries.indexed.map((val) {
              final index = val.$1;
              final entry = val.$2;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: index.isEven
                      ? Theme.of(context).colorScheme.secondary
                          .withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.tertiary
                          .withValues(alpha: 0.1),
                  borderRadius: index == 0
                      ? const BorderRadius.vertical(top: Radius.circular(8))
                      : index == attendances.length - 1
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(8))
                          : null,
                ),
                child: Row(
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

Map<String, String> getCombinedAttendances(Lessons lessons) {
  final attendances = <String, int>{};
  for (final lesson in lessons) {
    for (final entry in lesson.attendances!.entries) {
      final key = entry.key;
      final trimmed = entry.value.trim();
      final value = int.tryParse(trimmed) ??
          int.tryParse(
            RegExp(r'\d+').firstMatch(trimmed)?.group(0) ?? '',
          ) ??
          0;
      attendances.update(key, (val) => val + value, ifAbsent: () => value);
    }
  }
  return attendances.map((key, value) => MapEntry(key, value.toString()));
}
```

### Part B — Update the Navigator.push call in lessons_student_view.dart

- [ ] **Find the `Navigator.push` call for `AttendancesScreen`** in `lessons_student_view.dart`. It currently reads:

```dart
builder: (context) =>
    AttendancesScreen(lessons: attendanceLessons!),
```

Replace with:

```dart
builder: (context) => AttendancesScreen(
  lessons: attendanceLessons!,
  settings: settings,
  updateSetting: updateSetting,
),
```

- [ ] **Verify**

```bash
flutter analyze lib/applets/lessons/student/attendances.dart lib/applets/lessons/student/lessons_student_view.dart
```
Expected: `No issues found!`

- [ ] **Commit**

```bash
git add lib/applets/lessons/student/attendances.dart lib/applets/lessons/student/lessons_student_view.dart
git commit -m "feat(lessons): add attendance table view toggle (#479)"
```

---

## Task 4: Calendar category filter chips (#478)

**Files:**
- Modify: `lib/applets/calendar/calendar_view.dart`

The `_CalendarViewState` already holds `eventList`. We add `_activeFilterIds` state, a filter method, and a chip row between the search bar and the calendar.

- [ ] **Add `_activeFilterIds` field** to `_CalendarViewState` (after `bool noTrigger = false;`):

```dart
Set<int> _activeFilterIds = {};
```

- [ ] **Add `_applyFilter` helper method** to `_CalendarViewState` (after `_onDaySelected`):

```dart
List<CalendarEvent> _applyFilter(List<CalendarEvent> events) {
  if (_activeFilterIds.isEmpty) return events;
  return events.where((e) {
    if (e.category == null) return false;
    return _activeFilterIds.contains(e.category!.id);
  }).toList();
}
```

- [ ] **Update `_getEventsForDay` to apply filter**

Find the end of `_getEventsForDay`:
```dart
    return validEvents;
  }
```

Replace with:
```dart
    return _applyFilter(validEvents);
  }
```

- [ ] **Update `fuzzySearchEventList` to apply filter**

At the end of `fuzzySearchEventList`, before `return searchResults;` add:
```dart
    searchResults = _applyFilter(searchResults);
```

- [ ] **Add `_categoryChips` widget method** to `_CalendarViewState` (after `_applyFilter`):

```dart
Widget _categoryChips() {
  final categories = eventList
      .map((e) => e.category)
      .whereType<CalendarEventCategory>()
      .fold<Map<int, CalendarEventCategory>>({}, (map, cat) {
        map[cat.id] = cat;
        return map;
      })
      .values
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  if (categories.isEmpty) return const SizedBox.shrink();

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: const Text('Alle'),
            selected: _activeFilterIds.isEmpty,
            onSelected: (_) => setState(() => _activeFilterIds = {}),
          ),
        ),
        ...categories.map((cat) {
          final active = _activeFilterIds.contains(cat.id);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              avatar: CircleAvatar(backgroundColor: cat.color, radius: 8),
              label: Text(cat.name),
              selected: active,
              onSelected: (_) => setState(() {
                if (active) {
                  _activeFilterIds = Set.from(_activeFilterIds)
                    ..remove(cat.id);
                } else {
                  _activeFilterIds = Set.from(_activeFilterIds)..add(cat.id);
                }
                _selectedEvents.value = _getEventsForDay(_selectedDay!);
              }),
            ),
          );
        }),
      ],
    ),
  );
}
```

- [ ] **Insert chip row into the build layout**

In the `CombinedAppletBuilder` `builder:` callback, find:
```dart
eventList = data;
_selectedEvents.value = _getEventsForDay(_selectedDay!);

return LayoutBuilder(
```

Replace with:
```dart
eventList = data;
_selectedEvents.value = _getEventsForDay(_selectedDay!);

return Column(
  children: [
    _categoryChips(),
    Expanded(
      child: LayoutBuilder(
```

And close the new `Column` — find where the builder currently ends with just `);` closing the `LayoutBuilder` and add:
```dart
      ),
    ),
  ],
);
```

So the full builder return becomes:
```dart
return Column(
  children: [
    _categoryChips(),
    Expanded(
      child: LayoutBuilder(
        builder: (context, constrains) {
          if (constrains.maxWidth > 550) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _tableCalendar(context)),
                const VerticalDivider(),
                Expanded(child: _itemsListView(context)),
              ],
            );
          }
          return Column(
            children: [
              _tableCalendar(context),
              Expanded(child: _itemsListView(context)),
            ],
          );
        },
      ),
    ),
  ],
);
```

- [ ] **Verify**

```bash
flutter analyze lib/applets/calendar/calendar_view.dart
```
Expected: `No issues found!`

- [ ] **Commit**

```bash
git add lib/applets/calendar/calendar_view.dart
git commit -m "feat(calendar): add category filter chips (#478)"
```

---

## Task 5: Full analyze + final commit

- [ ] **Run full analyze**

```bash
flutter analyze lib/
```
Expected: `No issues found!`

- [ ] **Verify no regressions in related files**

```bash
flutter analyze lib/applets/lessons/ lib/applets/calendar/
```
Expected: `No issues found!`
