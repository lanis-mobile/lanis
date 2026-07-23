import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/study_groups/definitions.dart';
import 'package:lanis/applets/study_groups/student/student_course_view.dart';
import 'package:lanis/applets/study_groups/student/student_exams_view.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:liblanis/liblanis.dart';

class StudentStudyGroupsView extends ConsumerStatefulWidget {
  const StudentStudyGroupsView({super.key});

  @override
  ConsumerState<StudentStudyGroupsView> createState() =>
      _StudentStudyGroupsViewState();
}

class _StudentStudyGroupsViewState
    extends ConsumerState<StudentStudyGroupsView> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final parser = ref.watch(studyGroupsParserProvider);
    return CombinedAppletBuilder(
      parser: parser,
      phpUrl: studyGroupsDefinition.appletPhpUrl,
      settingsDefaults: studyGroupsDefinition.settingsDefaults,
      accountType: session.accountTypeOrNull ??
          ref.read(activeAccountProvider)?.accountType ??
          AccountType.student,
      showErrorAppBar: true,
      loadingAppBar: AppBar(),
      builder: (context, data, accountType, settings, updateSetting, refresh) {
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
              ? StudentExamsView(exams: data.sortedExams)
              : StudentCourseView(studyGroup: data.groups),
        );
      },
    );
  }
}
