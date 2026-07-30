import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/lessons/teacher/widgets/right_bottom_card_button.dart';
import 'package:lanis/applets/lessons/teacher/widgets/upload_file_to_course_chip.dart';

import 'course_folder_history_entry_file_chip.dart';
import 'line_constraint_text.dart';

import 'package:lanis/generated/l10n.dart';

enum _EntryMenuAction { delete, edit }

class CourseFolderHistoryEntryCard extends ConsumerStatefulWidget {
  final CourseFolderHistoryEntry entry;
  final String courseId;
  final void Function() afterDeleted;
  const CourseFolderHistoryEntryCard({
    super.key,
    required this.afterDeleted,
    required this.entry,
    required this.courseId,
  });

  @override
  ConsumerState<CourseFolderHistoryEntryCard> createState() =>
      _CourseFolderHistoryEntryCardState();
}

class _CourseFolderHistoryEntryCardState
    extends ConsumerState<CourseFolderHistoryEntryCard> {
  bool _showFiles = false;

  bool get _isToday {
    final now = DateTime.now();
    return widget.entry.date.year == now.year &&
        widget.entry.date.month == now.month &&
        widget.entry.date.day == now.day;
  }

  bool _isDayInFuture(DateTime date) {
    final now = DateTime.now();
    return date.isAfter(now);
  }

  void deleteEntryButtonPressed() async {
    final bool? delete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.deleteEntry),
          content: Text(l10n.confirmDeleteEntry),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (delete == true) {
      try {
        final result = await ref.read(lessonsTeacherParserProvider).deleteEntry(
          widget.courseId,
          widget.entry.id,
        );
        if (result) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).entryDeleted)),
            );
          }
          await Future.delayed(Duration(seconds: 1));
          widget.afterDeleted();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).entryDeleteFailed),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).entryDeleteFailed),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {},
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 8, top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            Icon(Icons.schedule, size: 18),
                            Text(
                              AppLocalizations.of(context).dateWithHours(
                                DateFormat.yMEd(
                                  Localizations.localeOf(context).toString(),
                                ).format(widget.entry.date),
                                widget.entry.schoolHours,
                              ),
                            ),
                            if (_isToday)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context).today,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            if (_isDayInFuture(widget.entry.date))
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: 4,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context).inAdvance,
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      Icon(
                                        widget.entry.isAvailableInAdvance
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        LineConstraintText(
                          data: widget.entry.topic,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<_EntryMenuAction>(
                  iconSize: 20,
                  onSelected: (_EntryMenuAction value) {
                    switch (value) {
                      case _EntryMenuAction.delete:
                        deleteEntryButtonPressed();
                      case _EntryMenuAction.edit:
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    final l10n = AppLocalizations.of(context);
                    return [
                      PopupMenuItem<_EntryMenuAction>(
                        value: _EntryMenuAction.delete,
                        child: Row(
                          children: [
                            Icon(Icons.delete),
                            const SizedBox(width: 4.0),
                            Text(l10n.deleteEntry),
                          ],
                        ),
                      ),
                      PopupMenuItem<_EntryMenuAction>(
                        value: _EntryMenuAction.edit,
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            const SizedBox(width: 4.0),
                            Text(l10n.editEntry),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 12.0,
                right: 12.0,
                bottom: 8.0,
              ),
              child: Column(
                children: [
                  if (widget.entry.content != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                          bottomLeft: widget.entry.homework == null
                              ? Radius.circular(8)
                              : Radius.zero,
                          bottomRight: widget.entry.homework == null
                              ? Radius.circular(8)
                              : Radius.zero,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.text_snippet_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LineConstraintText(
                              data: widget.entry.content!,
                              maxLines: 2,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onTertiaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.entry.homework != null) ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.only(
                          topLeft: widget.entry.content == null
                              ? Radius.circular(8)
                              : Radius.zero,
                          topRight: widget.entry.content == null
                              ? Radius.circular(8)
                              : Radius.zero,
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.task,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LineConstraintText(
                              data: widget.entry.homework!,
                              maxLines: 2,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                Spacer(),
                RightBottomCardButton(
                  text: 'Noten',
                  icon: Icons.star_border,
                  color: Colors.grey.shade300,
                  onColor: Colors.grey.shade900,
                  onTap: () {},
                  topLeftNotRounded: false,
                  bottomRightNotRounded: true,
                ),
                RightBottomCardButton(
                  text: 'Anwesenheiten️',
                  icon: widget.entry.attendanceActionRequired
                      ? Icons.error
                      : Icons.list_alt,
                  color: widget.entry.attendanceActionRequired
                      ? Colors.red.shade100
                      : Colors.blue.shade100,
                  onColor: widget.entry.attendanceActionRequired
                      ? Colors.red.shade900
                      : Colors.blue.shade900,
                  onTap: () {},
                  topLeftNotRounded: true,
                  bottomRightNotRounded: true,
                ),
                RightBottomCardButton(
                  text: widget.entry.studentUploadFileCount,
                  icon: Icons.download,
                  color: Colors.amber.shade100,
                  onColor: Colors.amber.shade900,
                  onTap: () {},
                  topLeftNotRounded: true,
                  bottomRightNotRounded: true,
                ),
                RightBottomCardButton(
                  text: widget.entry.files.length.toString(),
                  onTap: () {
                    setState(() {
                      _showFiles = !_showFiles;
                    });
                  },
                  topLeftNotRounded: true,
                  onColor: Colors.green.shade900,
                  icon: Icons.attach_file,
                  color: Colors.green.shade100,
                  isExpanded: _showFiles,
                ),
              ],
            ),
            if (_showFiles) ...[
              Divider(),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 8.0,
                  right: 12.0,
                  left: 12.0,
                ),
                child: Wrap(
                  spacing: 4.0,
                  alignment: WrapAlignment.start,
                  children: [
                    SizedBox(width: double.infinity),
                    ...widget.entry.files.map(
                      (file) => CourseFolderHistoryEntryFileChip(
                        file: file,
                        courseId: widget.courseId,
                        onVisibilityChanged: (bool isVisible) {
                          setState(() {
                            file.isVisibleForStudents = isVisible;
                          });
                        },
                        onFileDeleted: () {
                          setState(() {
                            widget.entry.files.remove(file);
                          });
                        },
                      ),
                    ),
                    UploadFileToCourseChip(
                      courseId: widget.courseId,
                      entryId: widget.entry.id,
                      onFileUploaded:
                          (List<CourseFolderHistoryEntryFile> files) {
                            setState(() {
                              widget.entry.files.addAll(files);
                            });
                          },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
