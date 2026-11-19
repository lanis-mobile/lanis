import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/widgets/applet_home_shell.dart';

List<RouteBase> buildTimetableRoutes(AppletRouteContext ctx) {
  return [
    for (final type in [AccountType.student, AccountType.parent])
      GoRoute(
        path: '/${type.name}/timetable',
        redirect: (context, state) {
          if (state.uri.path == '/${type.name}/timetable') {
            return timeTableDefinition.homePath(type);
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
