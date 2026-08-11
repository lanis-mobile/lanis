import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/applets/timetable/student/timetable_helper.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/utils/root_nav.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';


class StudentTimetableSettings extends ConsumerSettingsColours {
  final Function? openDrawerCb;
  final bool showBack;
  const StudentTimetableSettings({
    super.key,
    this.openDrawerCb,
    this.showBack = true,
  });

  @override
  ConsumerState<StudentTimetableSettings> createState() =>
      _StudentTimetableSettingsState();
}

class _StudentTimetableSettingsState
    extends ConsumerSettingsColoursState<StudentTimetableSettings> {
  List<TimetableDay> getSelectedPlan(
    TimeTable data,
    TimeTableType selectedType,
  ) {
    if (selectedType == TimeTableType.own) {
      return data.planForOwn ?? const [];
    }
    return data.planForAll ?? const [];
  }

  void showCustomLessonDialog(
    TimeTable currentTimetable,
    updateSettings,
    Map<String, dynamic> settings,
    List<List<TimetableSubject>>? customLessons,
    int currentDay, {
    TimetableSubject? lesson,
  }) {
    List<TimeTableRow>? hours = currentTimetable.hours;
    if (hours == null || hours.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noDataFound)),
      );
      return;
    }
    TimeTableRow startTime = hours[0];
    TimeTableRow endTime = hours[1];
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16.0,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    onChanged: (value) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: '${AppLocalizations.of(context).lessonName}*',
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
                  Row(
                    spacing: 8.0,
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
                    onPressed:
                        (nameController.text.isNotEmpty &&
                            hours.indexOf(startTime) <= hours.indexOf(endTime))
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
                              days[currentDay].remove(lesson);
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
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return SettingsPage(
        backgroundColor: backgroundColor,
        title: Text(AppLocalizations.of(context).timeTable),
        showBackButton: widget.showBack,
        children: const [
          Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    return SettingsPage(
      backgroundColor: backgroundColor,
      title: Text(AppLocalizations.of(context).timeTable),
      showBackButton: widget.showBack,
      children: [
        CombinedAppletBuilder<TimeTable>(
          parser: ref.watch(timetableParserProvider),
          phpUrl: timeTableDefinition.appletPhpUrl,
          settingsDefaults: timeTableDefinition.settingsDefaults,
          accountType: session.accountTypeOrNull ??
              ref.read(activeAccountProvider)?.accountType ??
              AccountType.student,
          builder: (context, timetable, _, settings, updateSettings, refresh) {
            final ids = settings['hidden-lessons'];
            Map<int, List<TimetableSubject>> lessons = {};

            for (var (dayIndex, day) in (timetable.planForAll ?? const []).indexed) {
              lessons[dayIndex] = [];
              if (ids == null) continue;
              for (var lesson in day) {
                if (!ids.contains(lesson.id)) continue;
                lessons[dayIndex]!.add(lesson);
              }
            }

            List<List<TimetableSubject>>? customLessons =
                TimeTableHelper.getCustomLessons(settings);

            // Prefer locale weekday names; fall back if symbols are empty
            // (some Platform.localeName values yield an empty WEEKDAYS list).
            final symbols = DateFormat.EEEE(
              Platform.localeName,
            ).dateSymbols.WEEKDAYS;
            final List<String> weekDays = symbols.length >= 7
                ? (symbols.sublist(1)..add(symbols.first))
                : const [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                    'Sunday',
                  ];

            return DefaultTabController(
              length: weekDays.length,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    tabs: weekDays
                        .map((dayName) => Tab(text: dayName))
                        .toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: weekDays.map((dayName) {
                        final currentDay = weekDays.indexOf(dayName);
                        final dayLessons = lessons[currentDay] ?? [];
                        final List<TimetableSubject>? customDayLessons =
                            (customLessons != null &&
                                currentDay >= 0 &&
                                currentDay < customLessons.length)
                            ? customLessons[currentDay]
                            : null;
                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              spacing: 8,
                              children: [
                                Card(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).hiddenLessons,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelLarge,
                                        ),
                                      ),
                                      if (dayLessons.isNotEmpty)
                                        ...dayLessons.map((lesson) {
                                          return ListTile(
                                            dense: true,
                                            title: Text(lesson.name ?? ''),
                                            subtitle: Text(
                                              "${lesson.startTime.toFlutter().format(context)} - ${lesson.endTime.toFlutter().format(context)}",
                                            ),
                                            trailing: IconButton(
                                              icon: Icon(Icons.delete),
                                              onPressed: () {
                                                setState(() {
                                                  updateSettings(
                                                    'hidden-lessons',
                                                    settings['hidden-lessons']
                                                      ..remove(lesson.id),
                                                  );
                                                });
                                              },
                                            ),
                                          );
                                        }),
                                      if (dayLessons.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).hiddenLessonsDescription,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall!
                                                .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Card(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).customLessons,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelLarge,
                                        ),
                                      ),
                                      if (customDayLessons != null &&
                                          customDayLessons.isNotEmpty)
                                        ...customDayLessons.map((lesson) {
                                          return ListTile(
                                            dense: true,
                                            title: Text(lesson.name ?? ''),
                                            subtitle: Text(
                                              "${lesson.startTime.toFlutter().format(context)} - ${lesson.endTime.toFlutter().format(context)}",
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: Icon(Icons.edit),
                                                  onPressed: () =>
                                                      showCustomLessonDialog(
                                                        timetable,
                                                        updateSettings,
                                                        settings,
                                                        customLessons,
                                                        currentDay,
                                                        lesson: lesson,
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.delete),
                                                  onPressed: () {
                                                    setState(() {
                                                      customLessons![currentDay]
                                                          .remove(lesson);
                                                      updateSettings(
                                                        'custom-lessons',
                                                        customLessons,
                                                      );
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 2.0,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              showCustomLessonDialog(
                                                timetable,
                                                updateSettings,
                                                settings,
                                                customLessons,
                                                currentDay,
                                              ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).addLesson,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      bottom: 32.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 28.0),
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20.0,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).customizeTimetableDisclaimer,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
