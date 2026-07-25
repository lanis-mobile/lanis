import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/substitutions/definition.dart';
import 'package:lanis/applets/substitutions/substitutions_filter_settings.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/widgets/applet_home_shell.dart';

List<RouteBase> buildSubstitutionRoutes(AppletRouteContext ctx) {
  final home = substitutionDefinition.homePath();
  return [
    GoRoute(
      path: '/common/substitutions',
      redirect: (context, state) {
        if (state.uri.path == '/common/substitutions') return home;
        return null;
      },
      routes: [
        appletHomeShell(
          homeBuilder: (context, state) =>
              ctx.homeBody(substitutionDefinition),
        ),
        GoRoute(
          path: 'filter',
          builder: (context, state) => DeepLinkPopScope(
            fallbackPath: home,
            child: const SubstitutionsFilterSettings(),
          ),
        ),
      ],
    ),
  ];
}
