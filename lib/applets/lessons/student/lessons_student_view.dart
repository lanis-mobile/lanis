import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

import '../../../core/sph/sph.dart';
import '../../../models/lessons.dart';
import 'all_marks_screen.dart';
import 'attendances.dart';
import 'lesson_list_tile.dart';

class LessonsStudentView extends StatefulWidget {
  final Function? openDrawerCb;
  const LessonsStudentView({super.key, this.openDrawerCb});

  @override
  State<StatefulWidget> createState() => _LessonsStudentViewState();
}

class _LessonsStudentViewState extends State<LessonsStudentView>
    with TickerProviderStateMixin {
  Widget noDataScreen(context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.search, size: 60),
        Text(AppLocalizations.of(context).noCoursesFound),
      ],
    ),
  );

  Map<String, dynamic>? globalSettings;
  Future<void> Function(String, dynamic)? globalUpdateSetting;
  Lessons? homeworkLessons;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.openDrawerCb != null
          ? AppBar(
              title: Text(lessonsDefinition.label(context)),
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              ),
              actions:
                  globalSettings != null &&
                      globalUpdateSetting != null &&
                      homeworkLessons != null &&
                      homeworkLessons!.isNotEmpty
                  ? [
                      globalSettings!['showHomework'] == true
                          ? Tooltip(
                              message: AppLocalizations.of(context).lessons,
                              child: IconButton(
                                icon: const Icon(Icons.school_outlined),
                                onPressed: () {
                                  globalUpdateSetting!('showHomework', false);
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    setState(() {});
                                  });
                                },
                              ),
                            )
                          : Tooltip(
                              message: AppLocalizations.of(context).homework,
                              child: IconButton(
                                icon: const Icon(Icons.task_outlined),
                                onPressed: () {
                                  globalUpdateSetting!('showHomework', true);
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    setState(() {});
                                  });
                                },
                              ),
                            ),
                    ]
                  : null,
            )
          : null,
      body: CombinedAppletBuilder<Lessons>(
        parser: sph!.parser.lessonsStudentParser,
        phpUrl: lessonsDefinition.appletPhpUrl,
        settingsDefaults: lessonsDefinition.settingsDefaults,
        accountType: sph!.session.accountType,
        builder:
            (context, lessons, accountType, settings, updateSetting, refresh) {
              Lessons? attendanceLessons;
              homeworkLessons = lessons
                  .where((element) => element.currentEntry?.homework != null)
                  .toList();

              if (globalUpdateSetting == null || globalSettings == null) {
                globalUpdateSetting = updateSetting;
                globalSettings = settings;
                if (settings['showHomework'] == true &&
                    homeworkLessons!.isEmpty) {
                  updateSetting('showHomework', false);
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {});
                });
              }

              if (settings['showHomework'] == true) {
                lessons = homeworkLessons!;

                lessons.sort((a, b) {
                  if (a.currentEntry!.homework!.homeWorkDone ==
                      b.currentEntry?.homework?.homeWorkDone) {
                    if (a.currentEntry?.topicDate != null &&
                        b.currentEntry?.topicDate != null) {
                      return a.currentEntry!.topicDate!.compareTo(
                        b.currentEntry!.topicDate!,
                      );
                    } else {
                      return a.currentEntry?.topicDate == null ? 1 : -1;
                    }
                  }
                  return (a.currentEntry?.homework?.homeWorkDone ?? false)
                      ? 1
                      : -1;
                });
              } else {
                final sortOption = settings['sortOption'] as String? ?? 'date_desc';
                lessons = _sortLessons(lessons, sortOption);
                attendanceLessons = lessons
                    .where((element) => element.attendances != null)
                    .toList();
              }

              return Scaffold(
                appBar: settings['showHomework'] != true
                    ? AppBar(
                        toolbarHeight: 0,
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(52),
                          child: _sortChips(settings, updateSetting),
                        ),
                      )
                    : null,
                body: RefreshIndicator(
                  onRefresh: () => refresh!(),
                  child: lessons.isNotEmpty
                      ? ListView.builder(
                          itemCount: lessons.length,
                          itemBuilder: (BuildContext context, int index) =>
                              Padding(
                                padding: EdgeInsets.only(
                                  top: 4,
                                  bottom: index == lessons.length - 1 ? 80 : 0,
                                  left: 8,
                                  right: 8,
                                ),
                                child: LessonListTile(lesson: lessons[index]),
                              ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [noDataScreen(context)],
                        ),
                ),
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
                            builder: (_) =>
                                AllMarksScreen(lessons: lessons),
                          ),
                        );
                      },
                      tooltip: AppLocalizations.of(context).allMarks,
                      child: const Icon(Icons.bar_chart),
                    ),
                    const SizedBox(height: 8),
                    Visibility(
                      visible:
                          attendanceLessons != null &&
                          attendanceLessons.isNotEmpty,
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
              );
            },
      ),
    );
  }
}
