import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/widgets/applet_home_shell.dart';

List<RouteBase> buildTimetableRoutes(AppletRouteContext ctx) {
  return [
    GoRoute(
      path: '/student/timetable',
      redirect: (context, state) {
        if (state.uri.path == '/student/timetable') {
          return timeTableDefinition.homePath(AccountType.student);
        }
        return null;
      },
      routes: [
        appletHomeShell(
          homeBuilder: (context, state) => ctx.homeBody(timeTableDefinition),
        ),
      ],
    ),
  ];
}
