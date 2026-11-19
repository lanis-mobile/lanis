import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/applets/lessons/student/attendances.dart';
import 'package:lanis/applets/lessons/student/course_overview.dart';
import 'package:lanis/applets/lessons/student/upload_page.dart';
import 'package:lanis/applets/lessons/teacher/course_detail_view/course_detail_view.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/widgets/applet_home_shell.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:liblanis/liblanis.dart';

List<RouteBase> buildLessonsRoutes(AppletRouteContext ctx) {
  return [
    ..._lessonsRoutesFor(AccountType.student, ctx),
    ..._lessonsRoutesFor(AccountType.parent, ctx),
    ..._lessonsRoutesFor(AccountType.teacher, ctx),
  ];
}

List<RouteBase> _lessonsRoutesFor(AccountType type, AppletRouteContext ctx) {
  final base = '/${type.name}/lessons';
  final home = '$base/home';
  return [
    GoRoute(
      path: base,
      redirect: (context, state) {
        if (state.uri.path == base) return home;
        return null;
      },
      routes: [
        appletHomeShell(
          homeBuilder: (context, state) => ctx.homeBody(lessonsDefinition),
        ),
        if (type == AccountType.student)
          GoRoute(
            path: 'course/:courseId',
            builder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final title = state.uri.queryParameters['title'] ?? courseId;
              final semester = state.uri.queryParameters['semester'];
              final tab = state.uri.queryParameters['tab'];
              final url = semester == '1'
                  ? 'meinunterricht.php?a=sus_view&id=$courseId&halb=1'
                  : 'meinunterricht.php?a=sus_view&id=$courseId';
              return DeepLinkPopScope(
                fallbackPath: home,
                child: CourseOverviewAnsicht(
                  dataFetchURL: url,
                  title: title,
                  initialTab: _tabIndex(tab),
                ),
              );
            },
          ),
        if (type == AccountType.student)
          GoRoute(
            path: 'attendances',
            builder: (context, state) => DeepLinkPopScope(
              fallbackPath: home,
              child: const LessonsAttendancesRoutePage(),
            ),
          ),
        if (type == AccountType.student)
          GoRoute(
            path: 'upload',
            builder: (context, state) {
              final url = state.uri.queryParameters['url'];
              final name = state.uri.queryParameters['name'] ?? '';
              final status = state.uri.queryParameters['status'] ?? 'open';
              if (url == null || url.isEmpty) {
                return DeepLinkErrorPage(
                  error: DeepLinkException('Missing upload url parameter'),
                  fallbackPath: home,
                );
              }
              return DeepLinkPopScope(
                fallbackPath: home,
                child: UploadScreen(
                  url: Uri.decodeComponent(url),
                  name: name,
                  status: status,
                ),
              );
            },
          ),
        if (type == AccountType.parent) ...[
          GoRoute(
            path: 'course/:courseId',
            builder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final url = Uri.tryParse(state.uri.queryParameters['url'] ?? '');
              if (url == null ||
                  url.path.split('/').last != 'meinunterricht.php' ||
                  (url.hasAuthority &&
                      url.host != 'start.schulportal.hessen.de') ||
                  (url.hasScheme && url.scheme != 'https') ||
                  url.queryParameters['id'] != courseId ||
                  (url.queryParameters['p']?.isEmpty ?? true)) {
                return DeepLinkErrorPage(
                  error: DeepLinkException(
                    'Missing or invalid parent course URL',
                  ),
                  fallbackPath: home,
                );
              }
              return DeepLinkPopScope(
                fallbackPath: home,
                child: CourseOverviewAnsicht(
                  dataFetchURL: url.toString(),
                  title: state.uri.queryParameters['title'] ?? courseId,
                  initialTab: _tabIndex(state.uri.queryParameters['tab']),
                  accountType: AccountType.parent,
                  pupilName: state.uri.queryParameters['pupilName'],
                ),
              );
            },
          ),
          GoRoute(
            path: 'attendances',
            builder: (context, state) => DeepLinkPopScope(
              fallbackPath: home,
              child: ParentLessonsAttendancesRoutePage(
                pupilId: state.uri.queryParameters['pupil'],
              ),
            ),
          ),
        ],
        if (type == AccountType.teacher)
          GoRoute(
            path: 'course/:courseId',
            builder: (context, state) {
              final courseId = state.pathParameters['courseId']!;
              final extra = state.extra;
              final folder = extra is CourseFolderStartPage
                  ? extra
                  : CourseFolderStartPage(
                      id: courseId,
                      name: state.uri.queryParameters['title'] ?? courseId,
                      topic: state.uri.queryParameters['topic'] ?? '',
                    );
              return DeepLinkPopScope(
                fallbackPath: home,
                child: TeacherCourseDetailView(courseFolder: folder),
              );
            },
          ),
      ],
    ),
  ];
}

int? _tabIndex(String? tab) {
  switch (tab) {
    case 'history':
      return 0;
    case 'performance':
      return 1;
    case 'exams':
      return 2;
    case 'attendances':
      return 3;
    default:
      return null;
  }
}

/// Loads lessons then shows [AttendancesScreen].
class LessonsAttendancesRoutePage extends ConsumerWidget {
  const LessonsAttendancesRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return Scaffold(
        appBar: attendanceAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final parser = ref.watch(lessonsStudentParserProvider);
    return CombinedAppletBuilder<Lessons>(
      parser: parser,
      phpUrl: lessonsDefinition.appletPhpUrl,
      settingsDefaults: lessonsDefinition.settingsDefaults,
      accountType: session.accountTypeOrNull ?? AccountType.student,
      loadingAppBar: attendanceAppBar(context),
      builder: (context, data, accountType, settings, updateSetting, refresh) {
        return AttendancesScreen(lessons: data);
      },
    );
  }
}

/// Parent attendance totals are scoped to one child, never combined across pupils.
class ParentLessonsAttendancesRoutePage extends ConsumerWidget {
  final String? pupilId;
  const ParentLessonsAttendancesRoutePage({super.key, required this.pupilId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionProvider).asData?.value == null) {
      return Scaffold(
        appBar: attendanceAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final parser = ref.watch(lessonsParentParserProvider);
    final pupilName = parser.latestResponse?.content?.lessonsByPupil.keys
        .where((pupil) => pupil.id == pupilId)
        .firstOrNull
        ?.name;
    return CombinedAppletBuilder<ParentLessonsOverview>(
      parser: parser,
      phpUrl: lessonsDefinition.appletPhpUrl,
      settingsDefaults: lessonsDefinition.settingsDefaults,
      accountType: AccountType.parent,
      loadingAppBar: attendanceAppBar(context, pupilName: pupilName),
      builder: (context, overview, type, settings, updateSetting, refresh) {
        final entry = overview.lessonsByPupil.entries
            .where((entry) => entry.key.id == pupilId)
            .firstOrNull;
        if (entry == null) {
          return DeepLinkErrorPage(
            error: DeepLinkException('Unknown pupil'),
            fallbackPath: '/parent/lessons/home',
          );
        }
        return AttendancesScreen(
          lessons: entry.value,
          pupilName: entry.key.name,
        );
      },
    );
  }
}
