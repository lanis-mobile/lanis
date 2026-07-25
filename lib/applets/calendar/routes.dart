import 'package:go_router/go_router.dart';
import 'package:lanis/applets/calendar/definition.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/widgets/applet_home_shell.dart';

List<RouteBase> buildCalendarRoutes(AppletRouteContext ctx) {
  return [
    GoRoute(
      path: '/common/calendar',
      redirect: (context, state) {
        if (state.uri.path == '/common/calendar') {
          return calendarDefinition.homePath();
        }
        return null;
      },
      routes: [
        appletHomeShell(
          homeBuilder: (context, state) => ctx.homeBody(calendarDefinition),
        ),
      ],
    ),
  ];
}
