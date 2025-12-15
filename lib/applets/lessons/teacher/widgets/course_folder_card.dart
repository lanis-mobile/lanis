import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../models/lessons_teacher.dart';

class CourseFolderCard extends StatelessWidget {
  final CourseFolderStartPage courseFolder;
  final void Function() onTap;
  const CourseFolderCard(
      {super.key, required this.courseFolder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                courseFolder.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (courseFolder.entryInformation?.date != null) ...[
              Text(
                  '${DateFormat('dd.MM.yyyy').format(courseFolder.entryInformation!.date)} ',
                  style: Theme.of(context).textTheme.bodyMedium),
              const Icon(Icons.calendar_today, size: 16)
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (courseFolder.entryInformation != null) ...[
              Row(
                spacing: 8,
                children: [
                  Icon(Icons.folder, size: 16),
                  Text(
                    courseFolder.topic,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(width: 0),
                ],
              ),
              if (courseFolder.entryInformation?.topic != null)
                Row(
                  spacing: 8,
                  children: [
                    Icon(Icons.topic, size: 16),
                    Expanded(
                      child: Text(
                        courseFolder.entryInformation!.topic,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                    SizedBox(width: 0),
                  ],
                ),
              if (courseFolder.entryInformation?.homework != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Icon(Icons.task,
                          color: Theme.of(context).colorScheme.onPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                        courseFolder.entryInformation!.homework!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      ))
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                ],
              ),
            ] else ...[
              Text(
                'No entry information available',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
      ),
    );
  }
}
