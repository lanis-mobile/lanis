import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/applets/timetable/student/student_timetable_better_view.dart';
import 'package:lanis/applets/timetable/student/timetable_helper.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/models/timetable.dart';
import 'package:lanis/utils/extensions.dart';

class ItemBlock extends StatelessWidget {
  final TimetableSubject? subject;
  final double height;
  final Color? color;
  final bool empty;
  final double offset;
  final double width;
  final double? hOffset;
  final bool onlyColor;
  final bool disableAction;

  final Map<String, dynamic> settings;
  final Function updateSettings;

  const ItemBlock({
    super.key,
    this.subject,
    required this.height,
    this.color,
    this.empty = false,
    required this.offset,
    required this.width,
    this.hOffset,
    this.onlyColor = false,
    required this.settings,
    required this.updateSettings,
    this.disableAction = false,
  });

  void showColorPicker(BuildContext context, Map<String, dynamic> settings,
      Function updateSettings, TimetableSubject lesson) {
    Color selectedColor = TimeTableHelper.getColorForLesson(settings, lesson);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: selectedColor,
              onColorChanged: (c) => {
                selectedColor = c,
              },
              enableAlpha: false,
              labelTypes: [],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text(AppLocalizations.of(context).clear),
              onPressed: () {
                updateSettings('lesson-colors', {
                  ...settings['lesson-colors'],
                  lesson.id!.split('-')[0]: null
                });

                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text(AppLocalizations.of(context).select),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();

                if (settings['lesson-colors'] == null) {
                  settings['lesson-colors'] = {};
                }
                updateSettings('lesson-colors', {
                  ...settings['lesson-colors'],
                  lesson.id!.split('-')[0]:
                      selectedColor.toHexString(enableAlpha: false)
                });
              },
            ),
          ],
        );
      },
    );
  }

  void showSubject(BuildContext context) {
    showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SizedBox(
            width: double.infinity,
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          subject?.name ??
                              AppLocalizations.of(context).unknownLesson,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Row(
                          children: [
                            IconButton(
                                onPressed: () {
                                  showColorPicker(context, settings,
                                      updateSettings, subject!);
                                },
                                icon: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle, color: color),
                                )),
                            if (subject != null &&
                                (subject?.id == null ||
                                    !subject!.id!.startsWith('custom')))
                              IconButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    updateSettings('hidden-lessons', [
                                      ...?settings['hidden-lessons'],
                                      subject!.id
                                    ]);
                                    showSnackbar(
                                        context,
                                        AppLocalizations.of(context)
                                            .lessonHidden(subject!.name!),
                                        seconds: 3);
                                  },
                                  icon: const Icon(
                                      Icons.visibility_off_outlined)),
                          ],
                        )
                      ],
                    ),
                  ),
                  if (subject?.raum != null)
                    modalSheetItem(subject!.raum!, Icons.place),
                  modalSheetItem(
                    "${subject!.startTime.format(context)} - ${subject!.endTime.format(context)} (${subject!.duration} ${subject!.duration == 1 ? "Stunde" : "Stunden"})",
                    Icons.access_time,
                  ),
                  if (subject?.lehrer != null)
                    modalSheetItem(subject!.lehrer!, Icons.person),
                  if (subject?.badge != null)
                    modalSheetItem(subject!.badge!, Icons.info),
                ],
              ),
            ),
          );
        });
  }

  Widget modalSheetItem(String content, IconData icon) {
    return Builder(builder: (context) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                icon,
                size: 24,
              ),
            ),
            Text(content, style: Theme.of(context).textTheme.labelLarge)
          ],
        ),
      );
    });
  }

  Widget _colorContainer(double width, {Widget? child}) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge, // Clips any overflow, useful for the y axis
      decoration: BoxDecoration(
        border: Border.all(
            color: color ?? Colors.transparent, width: min(1, width / 3)),
        color: color ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(4.0),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    TextStyle textStyle = TextStyle(
      fontSize: 12,
      color: color != null
          ? color!.computeLuminance() > 0.5
              ? Colors.black
              : Colors.white
          : null,
    );

    double calcWidth =
        max(1, width - ((width > (hOffset ?? 0)) ? (hOffset ?? 0) : 0));

    return Positioned(
      top: offset,
      left: hOffset,
      child: disableAction
          ? _colorContainer(calcWidth, child: SizedBox())
          : InkWell(
              onTap: subject != null ? () => showSubject(context) : null,
              child: _colorContainer(
                calcWidth,
                child: onlyColor
                    ? SizedBox()
                    : (!onlyColor && subject != null)
                        ? SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  runAlignment: WrapAlignment.spaceBetween,
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing:
                                      height % itemHeight >= 1.99 ? 99999 : 8.0,
                                  children: [
                                    Text(
                                      subject!.name ?? '',
                                      style: textStyle,
                                      maxLines: 1,
                                    ),
                                    if (subject!.lehrer != null)
                                      Text(
                                        subject!.lehrer!,
                                        style: textStyle,
                                        maxLines: 1,
                                      ),
                                  ],
                                ),
                                if (subject!.raum != null)
                                  Text(
                                    subject!.raum!,
                                    style: textStyle,
                                    maxLines: 1,
                                  ),
                              ],
                            ),
                          )
                        : SizedBox(),
              ),
            ),
    );
  }

  const ItemBlock.empty({
    super.key,
    required this.height,
    required this.offset,
    required this.width,
    required this.hOffset,
    required this.updateSettings,
    required this.settings,
  })  : subject = null,
        color = null,
        onlyColor = false,
        disableAction = true,
        empty = true;
}

class ListItem extends StatelessWidget {
  final int iteration;
  final TimeTableRow row;
  final TimeTableData data;
  final List<List<TimetableSubject>> timetableDays;
  final int i;
  final double width;
  final Map<String, dynamic> settings;
  final Function updateSettings;

  const ListItem({
    super.key,
    required this.iteration,
    required this.row,
    required this.data,
    required this.timetableDays,
    required this.i,
    required this.width,
    required this.settings,
    required this.updateSettings,
  });

  @override
  Widget build(BuildContext context) {
    double verticalOffset = 0;
    for (var j = 0; j < iteration; j++) {
      if (data.hours[j].type == TimeTableRowType.lesson) {
        verticalOffset += itemHeight;
      } else {
        verticalOffset += pauseHeight;
      }
      verticalOffset += 8;
    }

    double horizontalOffset = 0;

    final List<TimetableSubject> timetable = timetableDays[i];
    List<TimetableSubject> subjects = timetable.where((element) {
      return element.startTime == row.startTime;
    }).toList();

    List<TimetableSubject> subjectsInRow = timetable.where((element) {
      return row.startTime >= element.startTime &&
          row.endTime <= element.endTime;
    }).toList();

    // For pause rows, return a single Positioned widget
    if (row.type == TimeTableRowType.pause) {
      bool hidePause = false;
      for (var subject in subjectsInRow) {
        int numPauses = data.hours
            .where((element) =>
                element.type == TimeTableRowType.pause &&
                element.startTime >= subject.startTime &&
                element.endTime <= subject.endTime)
            .length;
        if (numPauses > 0) {
          hidePause = true;
          break;
        }
      }

      if (!hidePause) {
        return ItemBlock(
          height: pauseHeight,
          width: width,
          offset: verticalOffset,
          hOffset: horizontalOffset,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          onlyColor: true,
          settings: settings,
          updateSettings: updateSettings,
        );
      }
    }

    // If no subject, return an empty Positioned widget with a pre-determined height (or 0 height)
    if (subjects.isEmpty || row.type == TimeTableRowType.pause) {
      return ItemBlock.empty(
        height: 0,
        offset: verticalOffset,
        width: width,
        hOffset: horizontalOffset,
        updateSettings: updateSettings,
        settings: settings,
      );
    }

    // Determine horizontal space: calculate max overlapping subjects
    int maxSubjectsInRow = 0;
    for (var subject in subjects) {
      int maxSubjects = timetable.where((element) {
        return element.startTime >= subject.startTime &&
            element.startTime < subject.endTime;
      }).length;
      if (maxSubjects > maxSubjectsInRow) {
        maxSubjectsInRow = maxSubjects;
      }
    }

    subjectsInRow.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });

    return SizedBox(
      width: width,
      child: Stack(
        children: [
          for (var subject in subjects)
            Builder(builder: (context) {
              int indexInRow = subjectsInRow.indexOf(subject);
              int maxNum = max(maxSubjectsInRow, subjectsInRow.length);

              double hOffset = (width / maxNum) * indexInRow;

              int numPauses = data.hours
                  .where((element) =>
                      element.type == TimeTableRowType.pause &&
                      element.startTime >= subject.startTime &&
                      element.endTime <= subject.endTime)
                  .length;

              return ItemBlock(
                subject: subject,
                height: itemHeight * subject.duration +
                    ((subject.duration - 1) * 8) +
                    (numPauses * (pauseHeight + 8)),
                color: TimeTableHelper.getColorForLesson(settings, subject),
                offset: verticalOffset,
                // Calculate left offset based on subject index and max overlapping subjects
                hOffset: hOffset + (maxNum >= 2 ? 0 : 0),
                width: (width / maxNum) - (maxNum >= 2 ? 2 : 0),
                settings: settings,
                updateSettings: updateSettings,
                // Only show the color of the subject to save resources
                onlyColor: subjectsInRow.length > 3 &&
                    !(settings['single-day'] ?? false),
                disableAction: subjectsInRow.length > 6 &&
                    !(settings['single-day'] ?? false),
              );
            }),
        ],
      ),
    );
  }
}
