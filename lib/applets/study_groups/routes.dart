import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/study_groups/definition.dart';
import 'package:lanis/applets/study_groups/student/student_course_view.dart';
import 'package:lanis/applets/study_groups/student/student_exams_view.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:liblanis/liblanis.dart';

List<RouteBase> buildStudyGroupsRoutes(AppletRouteContext ctx) {
  return [
    GoRoute(
      path: '/student/study-groups',
      redirect: (context, state) {
        if (state.uri.path == '/student/study-groups') {
          return studyGroupsDefinition.homePath(AccountType.student);
        }
        return null;
      },
      routes: [
        GoRoute(
          path: 'home',
          builder: (context, state) =>
              const StudyGroupsModePage(showExams: false),
        ),
        GoRoute(
          path: 'exams',
          builder: (context, state) => DeepLinkPopScope(
            fallbackPath: studyGroupsDefinition.homePath(AccountType.student),
            child: const StudyGroupsModePage(showExams: true),
          ),
        ),
      ],
    ),
  ];
}

class StudyGroupsModePage extends ConsumerWidget {
  final bool showExams;

  const StudyGroupsModePage({super.key, required this.showExams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final openDrawer = Responsive.isTablet(context)
        ? null
        : () => Scaffold.of(context).openDrawer();
    final parser = ref.watch(studyGroupsParserProvider);
    return CombinedAppletBuilder(
      parser: parser,
      phpUrl: studyGroupsDefinition.appletPhpUrl,
      settingsDefaults: studyGroupsDefinition.settingsDefaults,
      accountType:
          session.accountTypeOrNull ??
          ref.read(activeAccountProvider)?.accountType ??
          AccountType.student,
      showErrorAppBar: true,
      loadingAppBar: AppBar(
        leading: openDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: openDrawer,
              )
            : null,
      ),
      builder: (context, data, accountType, settings, updateSetting, refresh) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              showExams
                  ? AppLocalizations.of(context).exams
                  : AppLocalizations.of(context).studyGroups,
            ),
            leading: openDrawer != null
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: openDrawer,
                  )
                : null,
            actions: [
              if (!showExams)
                Tooltip(
                  message: AppLocalizations.of(context).exams,
                  child: IconButton(
                    icon: const Icon(Icons.article_outlined),
                    onPressed: () =>
                        context.push('/student/study-groups/exams'),
                  ),
                )
              else
                Tooltip(
                  message: AppLocalizations.of(context).studyGroups,
                  child: IconButton(
                    icon: const Icon(Icons.groups_outlined),
                    onPressed: () =>
                        context.go(studyGroupsDefinition.homePath()),
                  ),
                ),
            ],
          ),
          body: showExams
              ? StudentExamsView(exams: data.sortedExams)
              : StudentCourseView(studyGroup: data.groups),
        );
      },
    );
  }
}
