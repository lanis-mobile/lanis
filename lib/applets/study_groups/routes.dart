import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/study_groups/definition.dart';
import 'package:lanis/applets/study_groups/student/student_course_view.dart';
import 'package:lanis/applets/study_groups/student/student_exams_view.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/widgets/applet_home_shell.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:liblanis/liblanis.dart';

List<RouteBase> buildStudyGroupsRoutes(AppletRouteContext ctx) {
  final home = studyGroupsDefinition.homePath(AccountType.student);
  return [
    GoRoute(
      path: '/student/study-groups',
      redirect: (context, state) {
        if (state.uri.path == '/student/study-groups') {
          return home;
        }
        return null;
      },
      routes: [
        appletHomeShell(
          homeBuilder: (context, state) => StudyGroupsModePage(
            showExams: state.uri.queryParameters['tab'] == 'exams',
          ),
        ),
        GoRoute(
          path: 'exams',
          redirect: (context, state) => Uri(
            path: home,
            queryParameters: const {'tab': 'exams'},
          ).toString(),
        ),
      ],
    ),
  ];
}

class StudyGroupsModePage extends ConsumerStatefulWidget {
  final bool showExams;
  final AppletDataSource<StudentStudyGroups>? dataSource;

  const StudyGroupsModePage({
    super.key,
    this.showExams = false,
    this.dataSource,
  });

  @override
  ConsumerState<StudyGroupsModePage> createState() =>
      _StudyGroupsModePageState();
}

class _StudyGroupsModePageState extends ConsumerState<StudyGroupsModePage> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.showExams ? 1 : 0;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant StudyGroupsModePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showExams != oldWidget.showExams) {
      final target = widget.showExams ? 1 : 0;
      if (target != _currentPage) {
        setState(() => _currentPage = target);
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    if (index == _currentPage) return;
    setState(() => _currentPage = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.dataSource == null
        ? ref.watch(sessionProvider).asData?.value
        : null;
    if (widget.dataSource == null && session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final openDrawer = Responsive.isTablet(context)
        ? null
        : () =>
              (HomeChrome.maybeOf(context)?.openDrawer ??
                      () => Scaffold.maybeOf(context)?.openDrawer())
                  .call();
    final AppletDataSource<StudentStudyGroups> parser =
        widget.dataSource ?? ref.watch(studyGroupsParserProvider);
    final l10n = AppLocalizations.of(context);

    return CombinedAppletBuilder<StudentStudyGroups>(
      parser: parser,
      phpUrl: studyGroupsDefinition.appletPhpUrl,
      settingsDefaults: studyGroupsDefinition.settingsDefaults,
      accountType:
          session?.accountTypeOrNull ??
          ref.read(activeAccountProvider)?.accountType ??
          AccountType.student,
      showErrorAppBar: true,
      loadingAppBar: AppBar(
        title: Text(l10n.studyGroups),
        leading: openDrawer != null
            ? IconButton(icon: const Icon(Icons.menu), onPressed: openDrawer)
            : null,
      ),
      builder: (context, data, accountType, settings, updateSetting, refresh) {
        final exams = data.sortedExams;
        final hasExams = exams.isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.studyGroups),
            leading: openDrawer != null
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: openDrawer,
                  )
                : null,
          ),
          body: !hasExams
              ? StudentCourseView(studyGroup: data.groups)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment<int>(
                              value: 0,
                              icon: const Icon(Icons.groups_outlined, size: 16),
                              label: Text(l10n.studyGroups),
                            ),
                            ButtonSegment<int>(
                              value: 1,
                              icon: const Icon(
                                Icons.article_outlined,
                                size: 16,
                              ),
                              label: Text(l10n.exams),
                            ),
                          ],
                          selected: {_currentPage},
                          onSelectionChanged: (selection) =>
                              _selectPage(selection.first),
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          if (index != _currentPage) {
                            setState(() => _currentPage = index);
                          }
                        },
                        children: [
                          StudentCourseView(studyGroup: data.groups),
                          StudentExamsView(exams: exams),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
