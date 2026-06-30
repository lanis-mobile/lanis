# Lessons Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement three new features in the Lessons applet: (1) message a teacher directly from a course, (2) view all marks from all courses in one screen, (3) a grade calculator with weighted mündlich/schriftlich categories and local manual notes.

**Architecture:** Feature 1 adds an AppBar action to `CourseOverviewAnsicht` that pre-fills `NewConversationConfigurator` via teacher name search. Feature 2 adds a new `AllMarksScreen` widget opened via FAB in `LessonsStudentView` that parallel-fetches all `DetailedLesson` data. Feature 3 adds a `GradeCalculatorCard` widget embedded in Tab 1 of `CourseOverviewAnsicht` with local persistence via `sph.prefs.kv`.

**Tech Stack:** Flutter/Dart, existing `sph.prefs.kv` (setAppletValue/getAppletValue), `ConversationsParser.searchTeacher()`, `LessonsStudentParser.getDetailedCourseView()`, `dart:convert` (jsonEncode/jsonDecode), Flutter `ExpansionTile`, `Slider`.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `lib/applets/lessons/student/course_overview.dart` | Modify | Add message-teacher AppBar button + GradeCalculatorCard in Tab 1 |
| `lib/applets/lessons/student/grade_calculator.dart` | Create | GradeCalculatorCard widget + grade parsing/calculation logic |
| `lib/applets/lessons/student/all_marks_screen.dart` | Create | AllMarksScreen — parallel fetch + expandable list |
| `lib/applets/lessons/student/lessons_student_view.dart` | Modify | Add second FAB for AllMarksScreen |
| `lib/l10n/intl_de.arb` | Modify | Add German strings for all three features |
| `lib/l10n/intl_en.arb` | Modify | Add English strings for all three features |

---

## Task 1: Add l10n strings for all three features

**Files:**
- Modify: `lib/l10n/intl_de.arb`
- Modify: `lib/l10n/intl_en.arb`

- [ ] **Step 1: Add German strings**

In `lib/l10n/intl_de.arb`, add before the closing `}`:

```json
  "messageTeacher": "Lehrer anschreiben",
  "messageTeacherSearching": "Suche Lehrer...",
  "messageTeacherNotFound": "Lehrer \"{name}\" nicht gefunden.",
  "@messageTeacherNotFound": { "placeholders": { "name": { "type": "String" } } },
  "messageTeacherMultipleFound": "Mehrere Lehrer gefunden. Bitte wähle einen aus:",
  "allMarks": "Alle Leistungen",
  "allMarksLoading": "{loaded} / {total} Kurse geladen",
  "@allMarksLoading": { "placeholders": { "loaded": { "type": "int" }, "total": { "type": "int" } } },
  "allMarksNoData": "Keine Leistungen gefunden.",
  "gradeCalculator": "Notenrechner",
  "gradeCalculatorAverage": "Durchschnitt",
  "gradeCalculatorWeighting": "Gewichtung",
  "gradeCalculatorOral": "Mündlich",
  "gradeCalculatorWritten": "Schriftlich",
  "gradeCalculatorOther": "Sonstig",
  "gradeCalculatorAddNote": "Note hinzufügen",
  "gradeCalculatorNoteName": "Bezeichnung",
  "gradeCalculatorNoteValue": "Note / Punkte",
  "gradeCalculatorUnknownFormat": "Unbekanntes Format"
```

- [ ] **Step 2: Add English strings**

In `lib/l10n/intl_en.arb`, add before the closing `}`:

```json
  "messageTeacher": "Message teacher",
  "messageTeacherSearching": "Searching for teacher...",
  "messageTeacherNotFound": "Teacher \"{name}\" not found.",
  "@messageTeacherNotFound": { "placeholders": { "name": { "type": "String" } } },
  "messageTeacherMultipleFound": "Multiple teachers found. Please select one:",
  "allMarks": "All grades",
  "allMarksLoading": "{loaded} / {total} courses loaded",
  "@allMarksLoading": { "placeholders": { "loaded": { "type": "int" }, "total": { "type": "int" } } },
  "allMarksNoData": "No grades found.",
  "gradeCalculator": "Grade calculator",
  "gradeCalculatorAverage": "Average",
  "gradeCalculatorWeighting": "Weighting",
  "gradeCalculatorOral": "Oral",
  "gradeCalculatorWritten": "Written",
  "gradeCalculatorOther": "Other",
  "gradeCalculatorAddNote": "Add grade",
  "gradeCalculatorNoteName": "Name",
  "gradeCalculatorNoteValue": "Grade / Points",
  "gradeCalculatorUnknownFormat": "Unknown format"
```

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/intl_de.arb lib/l10n/intl_en.arb
git commit -m "l10n: add strings for message-teacher, all-marks, grade-calculator features"
```

---

## Task 2: Feature #464 — Message teacher from CourseOverviewAnsicht

**Files:**
- Modify: `lib/applets/lessons/student/course_overview.dart`

- [ ] **Step 1: Add import for conversations**

At the top of `course_overview.dart`, add after the existing imports:

```dart
import '../../../applets/conversations/view/new_conversation_configurator.dart';
import '../../../applets/conversations/view/conversations_view.dart';
import '../../../models/conversations.dart';
```

- [ ] **Step 2: Add `_messageTeacher()` method to `_CourseOverviewAnsichtState`**

Add this method inside `_CourseOverviewAnsichtState`, before `_loadData`:

```dart
Future<void> _messageTeacher() async {
  if (data == null || data!.teachers.isEmpty) return;
  if (sph?.parser.conversationsParser == null) return;

  // Collect unique non-null teacher names
  final teacherNames = data!.teachers
      .map((t) => t.teacher)
      .where((n) => n != null)
      .cast<String>()
      .toList();

  if (teacherNames.isEmpty) return;

  if (!mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('Suche Lehrer...')),
      ]),
    ),
  );

  // Search all teachers in parallel
  final results = await Future.wait(
    teacherNames.map((name) =>
        sph!.parser.conversationsParser.searchTeacher(name)),
  );
  if (!mounted) return;
  Navigator.pop(context); // close loading dialog

  // Flatten: pair each result with the queried name
  final List<({String name, ReceiverEntry entry})> found = [];
  for (var i = 0; i < teacherNames.length; i++) {
    for (final entry in results[i]) {
      found.add((name: teacherNames[i], entry: entry));
    }
  }

  if (found.isEmpty) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).messageTeacher),
        content: Text(AppLocalizations.of(context)
            .messageTeacherNotFound(teacherNames.join(', '))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  ReceiverEntry receiver;
  if (found.length == 1) {
    receiver = found.first.entry;
  } else {
    // Let user pick
    final picked = await showDialog<ReceiverEntry>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(AppLocalizations.of(context).messageTeacherMultipleFound),
        children: found
            .map((f) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, f.entry),
                  child: Text('${f.entry.name} (${f.name})'),
                ))
            .toList(),
      ),
    );
    if (picked == null || !mounted) return;
    receiver = picked;
  }

  final chatData = await Navigator.push<ChatCreationData>(
    context,
    MaterialPageRoute(
      builder: (_) => NewConversationConfigurator(
        prefillReceiver: receiver,
      ),
    ),
  );
  if (chatData == null || !mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('Erstelle Nachricht...')),
      ]),
    ),
  );

  // We need a first message — open a text input dialog first
  // Actually: NewConversationConfigurator already handles the full flow.
  // Pop the loading dialog we just showed.
  if (mounted) Navigator.pop(context);

  await ConversationsViewState.sendNewConversationStatic(
    context,
    chatData,
    sph!,
  );
}
```

> **Note:** `NewConversationConfigurator` needs a `prefillReceiver` parameter (added in Task 2 Step 3). The static send method doesn't exist yet — simplify by navigating to `ConversationsView` instead (see Step 4).

- [ ] **Step 3: Add `prefillReceiver` parameter to `NewConversationConfigurator`**

In `lib/applets/conversations/view/new_conversation_configurator.dart`:

Add field to widget:
```dart
class NewConversationConfigurator extends StatefulWidget {
  final ReceiverEntry? prefillReceiver;  // ADD THIS
  const NewConversationConfigurator({super.key, this.prefillReceiver});  // ADD prefillReceiver
  // ... rest unchanged
}
```

In `_NewConversationConfiguratorState.initState()` — add after `super.initState()`:
```dart
@override
void initState() {
  super.initState();
  if (widget.prefillReceiver != null) {
    receivers.add(widget.prefillReceiver!);
  }
}
```

- [ ] **Step 4: Simplify `_messageTeacher()` — remove broken static call**

Replace the full `_messageTeacher()` from Step 2 with this cleaner version that just opens the configurator and lets it handle everything:

```dart
Future<void> _messageTeacher() async {
  if (data == null || data!.teachers.isEmpty) return;
  if (sph?.parser.conversationsParser == null) return;

  final teacherNames = data!.teachers
      .map((t) => t.teacher)
      .where((n) => n != null)
      .cast<String>()
      .toList();
  if (teacherNames.isEmpty) return;

  if (!mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('Suche Lehrer...')),
      ]),
    ),
  );

  final results = await Future.wait(
    teacherNames.map((n) =>
        sph!.parser.conversationsParser.searchTeacher(n)),
  );
  if (!mounted) return;
  Navigator.pop(context);

  final List<ReceiverEntry> found = results.expand((r) => r).toList();

  if (found.isEmpty) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).messageTeacher),
        content: Text(AppLocalizations.of(context)
            .messageTeacherNotFound(teacherNames.join(', '))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
    return;
  }

  ReceiverEntry receiver;
  if (found.length == 1) {
    receiver = found.first;
  } else {
    final picked = await showDialog<ReceiverEntry>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(
            AppLocalizations.of(context).messageTeacherMultipleFound),
        children: found
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, e),
                  child: Text(e.name),
                ))
            .toList(),
      ),
    );
    if (picked == null || !mounted) return;
    receiver = picked;
  }

  if (!mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => NewConversationConfigurator(
        prefillReceiver: receiver,
      ),
    ),
  );
}
```

- [ ] **Step 5: Add AppBar button**

In `build()` of `_CourseOverviewAnsichtState`, inside the `AppBar`'s `actions` list (after the existing semester1URL check), add:

```dart
if (sph?.parser.conversationsParser != null &&
    data!.teachers.any((t) => t.teacher != null))
  IconButton(
    icon: const Icon(Icons.mail_outline),
    tooltip: AppLocalizations.of(context).messageTeacher,
    onPressed: _messageTeacher,
  ),
```

- [ ] **Step 6: Verify imports in `course_overview.dart`**

Ensure these imports are present at the top:
```dart
import '../../../applets/conversations/view/new_conversation_configurator.dart';
import '../../../models/conversations.dart';
```

- [ ] **Step 7: Commit**

```bash
git add lib/applets/lessons/student/course_overview.dart \
        lib/applets/conversations/view/new_conversation_configurator.dart
git commit -m "feat(lessons): add message-teacher button in course overview (#464)"
```

---

## Task 3: Feature #469 — AllMarksScreen

**Files:**
- Create: `lib/applets/lessons/student/all_marks_screen.dart`
- Modify: `lib/applets/lessons/student/lessons_student_view.dart`

- [ ] **Step 1: Create `all_marks_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

import '../../../core/sph/sph.dart';
import '../../../models/lessons.dart';

class AllMarksScreen extends StatefulWidget {
  final Lessons lessons;
  const AllMarksScreen({super.key, required this.lessons});

  @override
  State<AllMarksScreen> createState() => _AllMarksScreenState();
}

class _AllMarksScreenState extends State<AllMarksScreen> {
  /// null = loading, non-null = result (may be empty list of marks)
  final Map<String, List<LessonMark>> _marksByCourseName = {};
  int _loaded = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    final total = widget.lessons.length;
    await Future.wait(
      widget.lessons.map((lesson) async {
        try {
          final detail =
              await sph!.parser.lessonsStudentParser.getDetailedCourseView(
            lesson.courseURL.toString(),
          );
          if (!mounted) return;
          setState(() {
            if (detail.marks.isNotEmpty) {
              _marksByCourseName[detail.name] = detail.marks;
            }
            _loaded++;
          });
        } catch (_) {
          if (!mounted) return;
          setState(() => _loaded++);
        }
      }),
    );
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.lessons.length;
    final courses = _marksByCourseName.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).allMarks),
      ),
      body: Column(
        children: [
          if (!_done)
            LinearProgressIndicator(value: total == 0 ? null : _loaded / total),
          if (!_done)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                AppLocalizations.of(context).allMarksLoading(_loaded, total),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: courses.isEmpty && _done
                ? Center(
                    child: Text(AppLocalizations.of(context).allMarksNoData),
                  )
                : ListView.builder(
                    itemCount: courses.length,
                    itemBuilder: (context, i) {
                      final entry = courses[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ExpansionTile(
                          title: Text(entry.key),
                          subtitle: Text(
                            '${entry.value.length} ${AppLocalizations.of(context).performance}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          children: entry.value
                              .map(
                                (mark) => ListTile(
                                  title: Text(mark.name),
                                  subtitle: Text(mark.date),
                                  trailing: Text(
                                    mark.mark,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add FAB to `LessonsStudentView`**

In `lib/applets/lessons/student/lessons_student_view.dart`, add import:
```dart
import 'all_marks_screen.dart';
```

In `build()`, the current `floatingActionButton` is a single `Visibility` widget. Replace it with a `Column` of two FABs (the existing Anwesenheiten FAB + a new Leistungen FAB):

```dart
floatingActionButton: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    FloatingActionButton.small(
      heroTag: 'allMarks',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllMarksScreen(lessons: lessons),
          ),
        );
      },
      tooltip: AppLocalizations.of(context).allMarks,
      child: const Icon(Icons.bar_chart),
    ),
    const SizedBox(height: 8),
    Visibility(
      visible: attendanceLessons != null && attendanceLessons.isNotEmpty,
      child: FloatingActionButton.extended(
        heroTag: 'attendances',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttendancesScreen(
                lessons: attendanceLessons!,
                settings: settings,
                updateSetting: updateSetting,
              ),
            ),
          );
        },
        label: Text(AppLocalizations.of(context).attendances),
        icon: const Icon(Icons.access_alarm),
      ),
    ),
  ],
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/applets/lessons/student/all_marks_screen.dart \
        lib/applets/lessons/student/lessons_student_view.dart
git commit -m "feat(lessons): add all-marks screen (#469)"
```

---

## Task 4: Feature #508 — GradeCalculatorCard

**Files:**
- Create: `lib/applets/lessons/student/grade_calculator.dart`
- Modify: `lib/applets/lessons/student/course_overview.dart`

- [ ] **Step 1: Create `grade_calculator.dart`**

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

import '../../../core/sph/sph.dart';
import '../../../models/lessons.dart';

enum GradeCategory { oral, written, other }

class _GradeEntry {
  final String name;
  final String rawValue;
  GradeCategory category;
  final bool isManual;

  _GradeEntry({
    required this.name,
    required this.rawValue,
    required this.category,
    this.isManual = false,
  });

  /// Returns the numeric value (in 1–6 scale or 0–15 points), or null if unparseable.
  double? get numericValue {
    final trimmed = rawValue.trim();
    // Try points system (0–15)
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null && asDouble >= 0 && asDouble <= 15) {
      if (asDouble > 6) return asDouble; // points mode — returned as-is
    }
    // Try 1–6 with +/-
    return _parseGermanGrade(trimmed);
  }

  bool get isPoints {
    final v = double.tryParse(rawValue.trim());
    return v != null && v > 6;
  }
}

/// Parses German school grades like "1+", "2-", "3" into decimal values.
/// Returns null for unrecognised formats.
double? _parseGermanGrade(String raw) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty) return null;
  final suffix = cleaned.endsWith('+')
      ? 1
      : cleaned.endsWith('-')
          ? -1
          : 0;
  final digit = double.tryParse(
    cleaned.replaceAll('+', '').replaceAll('-', ''),
  );
  if (digit == null || digit < 1 || digit > 6) return null;
  return digit - suffix * 0.33;
}

class GradeCalculatorCard extends StatefulWidget {
  final List<LessonMark> sphMarks;
  final String courseId;

  const GradeCalculatorCard({
    super.key,
    required this.sphMarks,
    required this.courseId,
  });

  @override
  State<GradeCalculatorCard> createState() => _GradeCalculatorCardState();
}

class _GradeCalculatorCardState extends State<GradeCalculatorCard> {
  static const _appletId = 'meinunterricht.php';
  late List<_GradeEntry> _entries;
  double _oralWeight = 0.5; // 0.0–1.0; written = 1 - oralWeight
  bool _loaded = false;

  String get _storageKey => 'grade-calc-${widget.courseId}';

  @override
  void initState() {
    super.initState();
    _entries = widget.sphMarks
        .map((m) => _GradeEntry(
              name: m.name,
              rawValue: m.mark,
              category: GradeCategory.other,
            ))
        .toList();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    final raw = await sph!.prefs.kv
        .getAppletValue(_appletId, _storageKey);
    if (raw == null) {
      setState(() => _loaded = true);
      return;
    }
    final Map<String, dynamic> data = jsonDecode(raw as String);
    final List cats = data['cats'] ?? [];
    final List manuals = data['manuals'] ?? [];
    final double? w = (data['oralWeight'] as num?)?.toDouble();

    setState(() {
      _oralWeight = w ?? 0.5;
      // Apply saved categories to existing SPH entries (matched by name+value)
      for (var i = 0; i < _entries.length && i < cats.length; i++) {
        _entries[i].category = GradeCategory.values[cats[i] as int];
      }
      // Re-add manual entries
      for (final m in manuals) {
        _entries.add(_GradeEntry(
          name: m['name'] as String,
          rawValue: m['value'] as String,
          category: GradeCategory.values[m['cat'] as int],
          isManual: true,
        ));
      }
      _loaded = true;
    });
  }

  Future<void> _saveLocal() async {
    final cats = _entries
        .where((e) => !e.isManual)
        .map((e) => e.category.index)
        .toList();
    final manuals = _entries
        .where((e) => e.isManual)
        .map((e) => {
              'name': e.name,
              'value': e.rawValue,
              'cat': e.category.index,
            })
        .toList();
    final payload = jsonEncode({
      'cats': cats,
      'manuals': manuals,
      'oralWeight': _oralWeight,
    });
    await sph!.prefs.kv.setAppletValue(_appletId, _storageKey, payload);
  }

  double? _average(List<_GradeEntry> entries) {
    final values = entries
        .map((e) => e.numericValue)
        .where((v) => v != null)
        .cast<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _formatAvg(double? avg, bool points) {
    if (avg == null) return '—';
    return points ? avg.toStringAsFixed(1) : avg.toStringAsFixed(2);
  }

  Future<void> _addManualNote() async {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    GradeCategory cat = GradeCategory.other;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(AppLocalizations.of(context).gradeCalculatorAddNote),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context).gradeCalculatorNoteName,
                ),
              ),
              TextField(
                controller: valueCtrl,
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context).gradeCalculatorNoteValue,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<GradeCategory>(
                segments: [
                  ButtonSegment(
                    value: GradeCategory.oral,
                    label:
                        Text(AppLocalizations.of(context).gradeCalculatorOral),
                  ),
                  ButtonSegment(
                    value: GradeCategory.written,
                    label: Text(
                        AppLocalizations.of(context).gradeCalculatorWritten),
                  ),
                  ButtonSegment(
                    value: GradeCategory.other,
                    label: Text(
                        AppLocalizations.of(context).gradeCalculatorOther),
                  ),
                ],
                selected: {cat},
                onSelectionChanged: (s) => setS(() => cat = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty ||
                    valueCtrl.text.trim().isEmpty) return;
                setState(() {
                  _entries.add(_GradeEntry(
                    name: nameCtrl.text.trim(),
                    rawValue: valueCtrl.text.trim(),
                    category: cat,
                    isManual: true,
                  ));
                });
                _saveLocal();
                Navigator.pop(ctx);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final oralEntries =
        _entries.where((e) => e.category == GradeCategory.oral).toList();
    final writtenEntries =
        _entries.where((e) => e.category == GradeCategory.written).toList();
    final otherEntries =
        _entries.where((e) => e.category == GradeCategory.other).toList();

    final hasPoints = _entries.any((e) => e.isPoints);

    final oralAvg = _average(oralEntries);
    final writtenAvg = _average(writtenEntries);
    final otherAvg = _average(otherEntries);

    double? weightedAvg;
    if (oralAvg != null && writtenAvg != null) {
      weightedAvg = oralAvg * _oralWeight + writtenAvg * (1 - _oralWeight);
    } else if (oralAvg != null) {
      weightedAvg = oralAvg;
    } else if (writtenAvg != null) {
      weightedAvg = writtenAvg;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ExpansionTile(
        title: Text(AppLocalizations.of(context).gradeCalculator),
        subtitle: weightedAvg != null
            ? Text(
                '${AppLocalizations.of(context).gradeCalculatorAverage}: '
                '${_formatAvg(weightedAvg, hasPoints)}',
              )
            : null,
        children: [
          // Category chips for each entry
          ..._entries.map((entry) {
            return ListTile(
              dense: true,
              title: Text(entry.name),
              subtitle: Text(entry.rawValue),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<GradeCategory>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: GradeCategory.oral,
                        label: Text(
                          AppLocalizations.of(context).gradeCalculatorOral,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      ButtonSegment(
                        value: GradeCategory.written,
                        label: Text(
                          AppLocalizations.of(context).gradeCalculatorWritten,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      ButtonSegment(
                        value: GradeCategory.other,
                        label: Text(
                          AppLocalizations.of(context).gradeCalculatorOther,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                    selected: {entry.category},
                    onSelectionChanged: (s) {
                      setState(() => entry.category = s.first);
                      _saveLocal();
                    },
                  ),
                  if (entry.isManual)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() => _entries.remove(entry));
                        _saveLocal();
                      },
                    ),
                ],
              ),
            );
          }),

          // Weighting slider (only useful when both oral and written exist)
          if (oralEntries.isNotEmpty || writtenEntries.isNotEmpty) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(AppLocalizations.of(context).gradeCalculatorOral),
                  Expanded(
                    child: Slider(
                      value: _oralWeight,
                      onChanged: (v) {
                        setState(() => _oralWeight = v);
                        _saveLocal();
                      },
                      divisions: 10,
                    ),
                  ),
                  Text(AppLocalizations.of(context).gradeCalculatorWritten),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${((_oralWeight) * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${((1 - _oralWeight) * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],

          // Averages summary
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (oralAvg != null)
                  Text(
                    '${AppLocalizations.of(context).gradeCalculatorOral}: '
                    '${_formatAvg(oralAvg, hasPoints)}',
                  ),
                if (writtenAvg != null)
                  Text(
                    '${AppLocalizations.of(context).gradeCalculatorWritten}: '
                    '${_formatAvg(writtenAvg, hasPoints)}',
                  ),
                if (otherAvg != null)
                  Text(
                    '${AppLocalizations.of(context).gradeCalculatorOther}: '
                    '${_formatAvg(otherAvg, hasPoints)}',
                  ),
                if (weightedAvg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${AppLocalizations.of(context).gradeCalculatorAverage}: '
                      '${_formatAvg(weightedAvg, hasPoints)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          // Add manual note button
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton.icon(
              onPressed: _addManualNote,
              icon: const Icon(Icons.add),
              label:
                  Text(AppLocalizations.of(context).gradeCalculatorAddNote),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Embed `GradeCalculatorCard` in Tab 1 of `CourseOverviewAnsicht`**

In `course_overview.dart`, add import:
```dart
import 'grade_calculator.dart';
```

In `_buildBody()`, `case 1:` (Leistungen), replace the existing `return` with:

```dart
case 1: // leistungen
  return data!.marks.isNotEmpty
      ? ListView.builder(
          itemCount: data!.marks.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return GradeCalculatorCard(
                sphMarks: data!.marks,
                courseId: data!.courseID,
              );
            }
            final mark = data!.marks[index - 1];
            return Padding(
              padding: EdgeInsets.only(
                left: padding,
                right: padding,
                bottom: index == data!.marks.length ? 14 : 8,
              ),
              child: Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        mark.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      trailing: Text(
                        mark.mark,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20.0,
                        ),
                      ),
                      subtitle: Text(
                        mark.date,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (mark.comment != null)
                      ListTile(
                        title: Text(
                          "${AppLocalizations.of(context).comment}: ",
                          style: Theme.of(context).textTheme.titleSmall,
                          textAlign: TextAlign.left,
                        ),
                        subtitle: Text(
                          mark.comment ?? "",
                          style: TextStyle(
                            fontSize: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .fontSize,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        )
      : noDataScreen(context);
```

- [ ] **Step 3: Commit**

```bash
git add lib/applets/lessons/student/grade_calculator.dart \
        lib/applets/lessons/student/course_overview.dart
git commit -m "feat(lessons): add grade calculator with weighted categories and manual notes (#508)"
```

---

## Task 5: Final verification

- [ ] **Step 1: Check for analysis errors**

```bash
flutter analyze lib/applets/lessons/student/ lib/applets/conversations/view/new_conversation_configurator.dart lib/l10n/
```

Expected: No errors. Warnings about unused imports are OK to fix.

- [ ] **Step 2: Manual smoke test checklist**

1. Open a course → Tab „Leistungen" → Notenrechner Card erscheint ausgeklappt
2. Kategorie einer Note ändern → Durchschnitt aktualisiert sich
3. Slider bewegen → Gewichtung ändert sich, Durchschnitt neu berechnet
4. „Note hinzufügen" → manuelle Note erscheint mit ×-Button
5. App neu starten → Kategorien und manuelle Noten sind noch da
6. Zurück zur Kursliste → zwei FABs sichtbar (Anwesenheiten + Leistungen-Chart)
7. Chart-FAB → AllMarksScreen öffnet, Ladebalken sichtbar, Kurse erscheinen
8. AppBar-Briefumschlag → Lehrer-Suche läuft, NewConversationConfigurator öffnet mit vorbeltem Empfänger

- [ ] **Step 3: Commit final polish if needed**

```bash
git add -p
git commit -m "fix(lessons): post-review polish for lessons features"
```
