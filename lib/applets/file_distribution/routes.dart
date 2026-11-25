import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/file_distribution/definition.dart';

const String fileDistributionHomePath = '/common/file-distribution/home';

String fileDistributionItemPath(int id) => '/common/file-distribution/item/$id';

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
        GoRoute(
          path: 'item/:id',
          redirect: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) return home;
            return Uri(
              path: home,
              queryParameters: {'id': '$id'},
            ).toString();
          },
        ),
      ],
    ),
  ];
}
