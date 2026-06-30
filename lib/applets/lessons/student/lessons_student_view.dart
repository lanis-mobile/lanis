import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

import '../../../core/sph/sph.dart';
import '../../../models/lessons.dart';
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
  Lessons? attendanceLessons;

  Lessons _sortLessons(Lessons lessons, String sortOption) {
    final sorted = List<Lesson>.from(lessons);
    switch (sortOption) {
      case 'date_asc':
        sorted.sort((a, b) {
          if (a.currentEntry?.topicDate == null) return 1;
          if (b.currentEntry?.topicDate == null) return -1;
          return a.currentEntry!.topicDate!.compareTo(b.currentEntry!.topicDate!);
        });
      case 'alpha_asc':
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case 'alpha_desc':
        sorted.sort((a, b) => b.name.compareTo(a.name));
      case 'teacher_asc':
        sorted.sort((a, b) {
          final aT = a.teachers.firstOrNull?.teacher ?? '';
          final bT = b.teachers.firstOrNull?.teacher ?? '';
          return aT.compareTo(bT);
        });
      case 'teacher_desc':
        sorted.sort((a, b) {
          final aT = a.teachers.firstOrNull?.teacher ?? '';
          final bT = b.teachers.firstOrNull?.teacher ?? '';
          return bT.compareTo(aT);
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

  Widget _sortButton(
    BuildContext context,
    Map<String, dynamic> settings,
    Future<void> Function(String, dynamic) updateSetting,
  ) {
    final current = settings['sortOption'] as String? ?? 'date_desc';
    final l10n = AppLocalizations.of(context);
    final options = [
      ('date_desc', l10n.sortDateDescending),
      ('date_asc', l10n.sortDateAscending),
      ('alpha_asc', l10n.sortNameAscending),
      ('alpha_desc', l10n.sortNameDescending),
      ('teacher_asc', l10n.sortTeacherAscending),
      ('teacher_desc', l10n.sortTeacherDescending),
    ];
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort),
      tooltip: l10n.sortBy,
      initialValue: current,
      onSelected: (value) => updateSetting('sortOption', value),
      itemBuilder: (_) => options
          .map((opt) => PopupMenuItem<String>(
                value: opt.$1,
                child: Row(
                  children: [
                    Expanded(child: Text(opt.$2)),
                    if (current == opt.$1)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ))
          .toList(),
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
                      homeworkLessons != null
                  ? [
                      if (globalSettings!['showHomework'] != true)
                        _sortButton(
                          context,
                          globalSettings!,
                          globalUpdateSetting!,
                        ),
                      if (homeworkLessons!.isNotEmpty)
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

              return RefreshIndicator(
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
              );
            },
      ),
      floatingActionButton: globalSettings != null &&
              globalUpdateSetting != null &&
              homeworkLessons != null &&
              globalSettings!['showHomework'] != true
          ? Builder(
              builder: (context) {
                return Visibility(
                  visible: false,
                  child: const SizedBox.shrink(),
                );
              },
            )
          : null,
    );
  }
}
