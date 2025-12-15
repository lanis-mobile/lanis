import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

import '../../../models/lessons.dart';

class AttendancesScreen extends StatelessWidget {
  const AttendancesScreen({super.key, required this.lessons});

  final Lessons lessons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).attendances),
      ),
      body: ListView.builder(
        itemCount: lessons.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                AttendanceCard(
                  title: AppLocalizations.of(context).allAttendances,
                  teachers: [],
                  attendances: getCombinedAttendances(lessons),
                ),
                Divider(),
              ],
            );
          }
          final lesson = lessons[index - 1];
          return AttendanceCard(
            title: lesson.name,
            teachers: lesson.teachers,
            attendances: lesson.attendances!,
          );
        },
      ),
    );
  }
}

class AttendanceCard extends StatelessWidget {
  final String title;
  final List<LessonTeacher> teachers;
  final Map<String, String> attendances;
  const AttendanceCard(
      {super.key,
      required this.attendances,
      required this.title,
      required this.teachers});

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
                    Text(
                      teachers.map((e) => e.teacherKuerzel).join(", "),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      teachers.length > 1 ? Icons.people : Icons.person,
                      size: 16,
                    ),
                  ]
                ],
              ),
            ),
            ...attendances.entries.indexed.map(
              (val) {
                final index = val.$1;
                final entry = val.$2;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? Theme.of(context)
                            .colorScheme
                            .secondary
                            .withValues(alpha: 0.3)
                        : Theme.of(context)
                            .colorScheme
                            .tertiary
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
                      Text(entry.key,
                          style: Theme.of(context).textTheme.bodyMedium),
                      const Spacer(),
                      Text(
                        entry.value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              },
            ),
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
      final value = int.tryParse(entry.value) ?? 0;
      attendances.update(key, (val) => val + value, ifAbsent: () => value);
    }
  }
  return attendances.map((key, value) => MapEntry(key, value.toString()));
}
