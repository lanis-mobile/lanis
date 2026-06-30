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
            tooltip: _isTableView
                ? AppLocalizations.of(context).attendancesCardView
                : AppLocalizations.of(context).attendancesTableView,
            onPressed: () async {
              await widget.updateSetting(
                'attendanceView',
                _isTableView ? 'cards' : 'table',
              );
              if (mounted) setState(() {});
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
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.secondaryContainer,
        ),
        columns: [
          DataColumn(label: Text(AppLocalizations.of(context).attendancesCourseColumn)),
          ...allKeys.map((k) => DataColumn(label: Text(k))),
        ],
        rows: [
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
    if (lesson.attendances == null) continue;
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
