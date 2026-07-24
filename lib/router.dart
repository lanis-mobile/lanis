import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/substitutions/substitutions_filter_settings.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/startup.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/view/account_switcher/account_switcher.dart';
import 'package:lanis/view/login/auth.dart';
import 'package:lanis/view/login/screen.dart';
import 'package:lanis/view/moodle.dart';
import 'package:lanis/view/settings/settings.dart';
import 'package:lanis/view/settings/subsettings/appearance.dart';
import 'package:lanis/view/settings/subsettings/cache.dart';
import 'package:lanis/view/settings/subsettings/notifications.dart';
import 'package:lanis/view/settings/subsettings/about.dart';
import 'package:lanis/view/settings/subsettings/userdata.dart';
import 'package:lanis/view/settings/subsettings/quick_actions.dart';
import 'package:lanis/view/settings/subsettings/navigation_rail_settings.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

Widget _homeAppletBody(AppletDefinition def) {
  return Consumer(
    builder: (context, ref, _) {
      final accountType =
          ref.watch(activeAccountProvider.select((a) => a?.accountType)) ??
          AccountType.student;
      final openDrawer = () => Scaffold.of(context).openDrawer();
      final builder = def.bodyBuilder;
      if (builder == null) {
        return const SizedBox.shrink();
      }
      return builder(context, accountType, openDrawer);
    },
  );
}

bool _isSupportedHomePath(Ref ref, String loc) {
  for (final def in AppDefinitions.homeApplets) {
    if (loc == def.routePath || loc.startsWith('${def.routePath}/')) {
      return ref
          .read(supportedAppletPhpUrlsProvider)
          .contains(def.appletPhpUrl);
    }
  }
  return true;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Do not watch auth here — recreating GoRouter resets the navigation stack.
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  final homeBranches = [
    for (final def in AppDefinitions.homeApplets)
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: def.routePath,
            builder: (context, state) => _homeAppletBody(def),
            routes: [
              if (def.appletPhpUrl == 'vertretungsplan.php')
                GoRoute(
                  path: 'filter',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                      const SubstitutionsFilterSettings(),
                ),
            ],
          ),
        ],
      ),
  ];

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/startup',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final loggingIn = loc == '/welcome' || loc == '/login';
      final onStartup = loc == '/startup';
      final onHome = loc.startsWith('/home');

      switch (auth.phase) {
        case AuthPhase.authenticating:
          // Keep /login and /accounts mounted so add-account / switch can
          // surface failures instead of being torn down mid-auth.
          if (onStartup || loc == '/login' || loc == '/accounts') return null;
          return '/startup';
        case AuthPhase.unauthenticated:
          if (loggingIn || onStartup) {
            if (onStartup) return '/welcome';
            return null;
          }
          return '/welcome';
        case AuthPhase.error:
          // Allow /login so WrongCredentials "Log In" can reach the form.
          if (loc == '/login') return null;
          return onStartup ? null : '/startup';
        case AuthPhase.authenticated:
          // Allow /login so "add account" works while already signed in.
          if (loggingIn && loc == '/login') return null;
          if (loc == '/welcome' || onStartup) {
            return firstSupportedHomePathFromRef(ref);
          }
          if (onHome && !_isSupportedHomePath(ref, loc)) {
            return firstSupportedHomePathFromRef(ref);
          }
          final supported = ref.read(supportedAppletPhpUrlsProvider);
          for (final def in AppDefinitions.navigationApplets) {
            if (loc == def.routePath || loc.startsWith('${def.routePath}/')) {
              if (!supported.contains(def.appletPhpUrl)) {
                return firstSupportedHomePathFromRef(ref);
              }
            }
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeLoginScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const Scaffold(body: LoginForm(showBackButton: true)),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomePage(navigationShell: navigationShell);
        },
        branches: homeBranches,
      ),
      for (final def in AppDefinitions.navigationApplets)
        GoRoute(
          path: def.routePath,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => Consumer(
            builder: (context, ref, _) {
              final accountType = ref.watch(
                    activeAccountProvider.select((a) => a?.accountType),
                  ) ??
                  AccountType.student;
              final builder = def.bodyBuilder;
              if (builder == null) return const SizedBox.shrink();
              return builder(context, accountType, null);
            },
          ),
        ),
      GoRoute(
        path: '/moodle',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MoodleWebView(),
      ),
      GoRoute(
        path: '/accounts',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AccountSwitcher(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'appearance',
            builder: (context, state) => const AppearanceSettings(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationSettings(),
          ),
          GoRoute(
            path: 'cache',
            builder: (context, state) => const CacheSettings(),
          ),
          GoRoute(
            path: 'quick-actions',
            builder: (context, state) => const QuickActions(),
          ),
          GoRoute(
            path: 'navigation-rail',
            builder: (context, state) => const NavigationRailSettingsPage(),
          ),
          GoRoute(
            path: 'userdata',
            builder: (context, state) => const UserDataSettings(),
          ),
          GoRoute(
            path: 'about',
            builder: (context, state) => const AboutSettings(),
          ),
        ],
      ),
    ],
  );
});

/// Notifies [GoRouter] when auth phase changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this.ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }

  final Ref ref;
}
