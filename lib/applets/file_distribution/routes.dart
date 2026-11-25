import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/file_distribution/definition.dart';

List<RouteBase> buildFileDistributionRoutes(AppletRouteContext ctx) {
  final home = fileDistributionDefinition.homePath();
  return [
    GoRoute(
      path: '/common/file-distribution',
      redirect: (context, state) {
        if (state.uri.path == '/common/file-distribution') return home;
        return null;
      },
      routes: [
        GoRoute(
          path: 'home',
          builder: (context, state) =>
              ctx.homeBody(fileDistributionDefinition),
        ),
      ],
    ),
  ];
}
