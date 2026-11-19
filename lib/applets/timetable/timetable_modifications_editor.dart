import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:lanis/utils/root_nav.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'student/timetable_helper.dart';

List<String> _weekDays(BuildContext context) => List.generate(
  7,
  (day) => DateFormat.EEEE(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(DateTime(2024, 1, 1 + day)),
);

class TimetableModificationsEditor extends StatefulWidget {
  final TimeTable timetable;
  final Map<String, dynamic> settings;
  final UpdateSetting updateSettings;
  const TimetableModificationsEditor({
    super.key,
    required this.timetable,
    required this.settings,
    required this.updateSettings,
  });
  @override
  State<TimetableModificationsEditor> createState() =>
      _TimetableModificationsEditorState();
}

class _TimetableModificationsEditorState
    extends State<TimetableModificationsEditor> {
  void showCustomLessonDialog(
    TimeTable currentTimetable,
    updateSettings,
    Map<String, dynamic> settings,
    List<List<TimetableSubject>>? customLessons,
    int currentDay, {
    TimetableSubject? lesson,
  }) {
    final originalDay = currentDay;
    final weekDays = _weekDays(context);
    List<TimeTableRow>? hours = currentTimetable.hours;
    if (hours == null || hours.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noDataFound)),
      );
      return;
    }
    TimeTableRow startTime = hours[0];
    TimeTableRow endTime = hours.first;
    int selectedWeek = 0;
    List<String?> allBadges = (currentTimetable.planForAll ?? const [])
        .expand((day) => day.map((lesson) => lesson.badge))
        .where((badge) => badge != null)
        .toSet()
        .toList();
    final String noBadge = '-';
    final TextEditingController nameController = TextEditingController();
    final TextEditingController teacherController = TextEditingController();
    final TextEditingController roomController = TextEditingController();
    int duration = 1;

    if (lesson != null) {
      nameController.text = lesson.name ?? '';
      teacherController.text = lesson.lehrer ?? '';
      roomController.text = lesson.raum ?? '';
      startTime = hours.firstWhere(
        (hour) => hour.startTime == lesson.startTime,
        orElse: () => hours.first,
      );
      endTime = hours.firstWhere(
        (hour) => hour.endTime == lesson.endTime,
        orElse: () => hours.last,
      );
      if (lesson.badge != null && !allBadges.contains(lesson.badge)) {
        allBadges.add(lesson.badge);
      }
      selectedWeek = lesson.badge == null
          ? 0
          : allBadges.indexOf(lesson.badge) + 1;
      duration = lesson.duration;
    }

    showRootModalBottomSheet(
      showDragHandle: true,
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      builder: (context1) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32.0,
            right: 16.0,
            left: 16.0,
            top: 16.0,
          ),
          child: StatefulBuilder(
            builder: (context1, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16.0,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      key: const ValueKey('custom-lesson-weekday'),
                      initialValue: currentDay,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).day,
                      ),
                      items: [
                        for (var day = 0; day < 7; day++)
                          DropdownMenuItem(
                            value: day,
                            child: Text(weekDays[day]),
                          ),
                      ],
                      onChanged: (day) => setState(() => currentDay = day!),
                    ),
                    TextField(
                      key: const ValueKey('custom-lesson-name'),
                      controller: nameController,
                      onChanged: (value) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText:
                            '${AppLocalizations.of(context).lessonName}*',
                        helperText: '*${AppLocalizations.of(context).required}',
                      ),
                    ),
                    Row(
                      spacing: 8.0,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: teacherController,
                            onChanged: (value) {
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).teacher,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: roomController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).room,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownMenu(
                          width: 100,
                          initialSelection: startTime.label,
                          onSelected: (value) {
                            setState(() {
                              startTime = hours.firstWhere(
                                (hour) => hour.label == value,
                              );
                              duration =
                                  hours.indexOf(endTime) -
                                  hours.indexOf(startTime) +
                                  1;
                            });
                          },
                          dropdownMenuEntries: hours
                              .map(
                                (hour) => DropdownMenuEntry(
                                  value: hour.label,
                                  label: hour.label,
                                ),
                              )
                              .toList(),
                        ),
                        Text('-'),
                        DropdownMenu(
                          width: 100,
                          initialSelection: endTime.label,
                          onSelected: (value) {
                            setState(() {
                              endTime = hours.firstWhere(
                                (hour) => hour.label == value,
                              );
                              duration =
                                  hours.indexOf(endTime) -
                                  hours.indexOf(startTime) +
                                  1;
                            });
                          },
                          dropdownMenuEntries: hours
                              .map(
                                (hour) => DropdownMenuEntry(
                                  value: hour.label,
                                  label: hour.label,
                                ),
                              )
                              .toList(),
                        ),
                        if (allBadges.isNotEmpty)
                          DropdownMenu(
                            width: 130.0,
                            label: Text(AppLocalizations.of(context).week),
                            initialSelection: [
                              noBadge,
                              ...allBadges,
                            ][selectedWeek],
                            onSelected: (value) {
                              setState(() {
                                selectedWeek = [
                                  noBadge,
                                  ...allBadges,
                                ].indexOf(value!);
                              });
                            },
                            dropdownMenuEntries: [noBadge, ...allBadges]
                                .map(
                                  (badge) => DropdownMenuEntry(
                                    value: badge,
                                    label: badge != noBadge
                                        ? AppLocalizations.of(
                                            context,
                                          ).timetableWeek(badge ?? '')
                                        : badge!,
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                    ElevatedButton(
                      key: const ValueKey('save-custom-lesson'),
                      onPressed:
                          (nameController.text.isNotEmpty &&
                              hours.indexOf(startTime) <=
                                  hours.indexOf(endTime))
                          ? () {
                              TimetableSubject newLesson = TimetableSubject(
                                id: 'custom${nameController.text.replaceAll('-', '_')}-$currentDay-${startTime.startTime.hour}-${startTime.startTime.minute}',
                                name: nameController.text,
                                raum: roomController.text.isEmpty
                                    ? null
                                    : roomController.text,
                                lehrer: teacherController.text,
                                badge: selectedWeek == 0
                                    ? null
                                    : allBadges[selectedWeek - 1],
                                duration: duration,
                                startTime: startTime.startTime,
                                endTime: endTime.endTime,
                                stunde: hours.indexOf(startTime),
                              );

                              if (settings['custom-lessons'] == null) {
                                settings['custom-lessons'] = ',,,,,,,'
                                    .split(',')
                                    .map((_) => [])
                                    .toList();
                              }

                              List<List<TimetableSubject>> days =
                                  TimeTableHelper.getCustomLessons(settings) ??
                                  List.generate(7, (_) => <TimetableSubject>[]);
                              while (days.length <= currentDay) {
                                days.add(<TimetableSubject>[]);
                              }

                              if (lesson != null) {
                                days[originalDay].remove(lesson);
                              }
                              days[currentDay].add(newLesson);

                              updateSettings('custom-lessons', days);
                              popRootDialog(context1);
                              showSnackbar(
                                context,
                                AppLocalizations.of(
                                  context,
                                ).lessonAdded(newLesson.name!),
                              );
                            }
                          : null,
                      child: Text(
                        lesson == null
                            ? AppLocalizations.of(context).addLesson
                            : AppLocalizations.of(context).editLesson,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = AppLocalizations.of(context);
    final custom = TimeTableHelper.getCustomLessons(widget.settings);
    final days = _weekDays(context);
    final customEntries = [
      for (var day = 0; day < (custom?.length ?? 0); day++)
        for (final lesson in custom![day]) (day, lesson),
    ];
    final hiddenIds = widget.settings['hidden-lessons'] as List? ?? [];
    final hiddenEntries = [
      for (var day = 0; day < (widget.timetable.planForAll?.length ?? 0); day++)
        for (final lesson in widget.timetable.planForAll![day])
          if (hiddenIds.contains(lesson.id)) (day, lesson),
    ];
    int order((int, TimetableSubject) a, (int, TimetableSubject) b) {
      final day = a.$1.compareTo(b.$1);
      if (day != 0) return day;
      final time = (a.$2.startTime.hour * 60 + a.$2.startTime.minute).compareTo(
        b.$2.startTime.hour * 60 + b.$2.startTime.minute,
      );
      return time != 0 ? time : (a.$2.name ?? '').compareTo(b.$2.name ?? '');
    }

    customEntries.sort(order);
    hiddenEntries.sort(order);
    String subtitle((int, TimetableSubject) entry) => [
      days[entry.$1],
      '${entry.$2.startTime.toFlutter().format(context)} – ${entry.$2.endTime.toFlutter().format(context)}',
      if (entry.$2.badge != null) labels.timetableWeek(entry.$2.badge!),
    ].join(' · ');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                labels.customLessons,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              key: const ValueKey('add-custom-lesson'),
              onPressed: () => showCustomLessonDialog(
                widget.timetable,
                widget.updateSettings,
                widget.settings,
                custom,
                DateTime.now().weekday - 1,
              ),
              icon: const Icon(Icons.add),
              label: Text(labels.addLesson),
            ),
          ],
        ),
        for (final entry in customEntries)
          Card(
            child: ListTile(
              title: Text(entry.$2.name ?? ''),
              subtitle: Text(subtitle(entry)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: labels.editEntry,
                    onPressed: () => showCustomLessonDialog(
                      widget.timetable,
                      widget.updateSettings,
                      widget.settings,
                      custom,
                      entry.$1,
                      lesson: entry.$2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: labels.deleteEntry,
                    onPressed: () {
                      custom![entry.$1].remove(entry.$2);
                      widget.updateSettings('custom-lessons', custom);
                    },
                  ),
                ],
              ),
            ),
          ),
        if (hiddenEntries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            labels.hiddenLessons,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final entry in hiddenEntries)
            Card(
              child: ListTile(
                title: Text(entry.$2.name ?? ''),
                subtitle: Text(subtitle(entry)),
                trailing: IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: labels.hideShow,
                  onPressed: () => widget.updateSettings(
                    'hidden-lessons',
                    List<dynamic>.from(hiddenIds)..remove(entry.$2.id),
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        Icon(
          Icons.info_outline_rounded,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(
          labels.customizeTimetableDisclaimer,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
