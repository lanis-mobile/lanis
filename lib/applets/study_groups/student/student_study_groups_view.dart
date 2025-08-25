import 'package:flutter/material.dart';
import 'package:lanis/applets/study_groups/definitions.dart';
import 'package:lanis/applets/study_groups/student/student_course_view.dart';
import 'package:lanis/applets/study_groups/student/student_exams_view.dart';
import 'package:lanis/core/sph/sph.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/models/study_groups.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

class StudentStudyGroupsView extends StatefulWidget {
  const StudentStudyGroupsView({super.key});

  @override
  State<StudentStudyGroupsView> createState() => _StudentStudyGroupsViewState();
}

class _StudentStudyGroupsViewState extends State<StudentStudyGroupsView> {
  @override
  Widget build(BuildContext context) {
    return CombinedAppletBuilder(
        parser: sph!.parser.studyGroupsStudentParser,
        phpUrl: studyGroupsDefinition.appletPhpUrl,
        settingsDefaults: studyGroupsDefinition.settingsDefaults,
        accountType: sph!.session.accountType,
        showErrorAppBar: true,
        loadingAppBar: AppBar(),
        builder:
            (context, data, accountType, settings, updateSetting, refresh) {
          List<StudentStudyGroupsContainer> studyData =
              data.expand((studyGroup) {
            final exams = studyGroup.exams;
            if (exams == null) {
              return const Iterable<StudentStudyGroupsContainer>.empty();
            }
            return exams.map((exam) => StudentStudyGroupsContainer(
                  halfYear: studyGroup.halfYear,
                  courseName: studyGroup.courseName,
                  teacher: studyGroup.teacher,
                  teacherKuerzel: studyGroup.teacherKuerzel,
                  exam: exam,
                ));
          }).toList();

          studyData.sort((a, b) => a.exam.date.compareTo(b.exam.date));

          return Scaffold(
            appBar: AppBar(
              title: settings['showExams'] != 'true'
                  ? Text(AppLocalizations.of(context).studyGroups)
                  : Text(AppLocalizations.of(context).exams),
              actions: [
                settings['showExams'] != 'true'
                    ? Tooltip(
                        message: AppLocalizations.of(context).exams,
                        child: IconButton(
                          icon: Icon(Icons.article_outlined),
                          onPressed: () => updateSetting('showExams', 'true'),
                        ),
                      )
                    : Tooltip(
                        message: AppLocalizations.of(context).studyGroups,
                        child: IconButton(
                          icon: Icon(Icons.groups_outlined),
                          onPressed: () => updateSetting('showExams', 'false'),
                        ),
                      ),
              ],
            ),
            body: settings['showExams'] == 'true'
                ? StudentExamsView(studyData: studyData)
                : StudentCourseView(studyData: data),
          );
        });
  }
}
