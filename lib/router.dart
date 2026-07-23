import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/calendar/calendar_view.dart';
import 'package:lanis/applets/conversations/view/conversations_view.dart';
import 'package:lanis/applets/data_storage/data_storage_root_view.dart';
import 'package:lanis/applets/lessons/student/lessons_student_view.dart';
import 'package:lanis/applets/lessons/teacher/lessons_teacher_view.dart';
import 'package:lanis/applets/study_groups/student/student_study_groups_view.dart';
import 'package:lanis/applets/substitutions/substitutions_filter_settings.dart';
import 'package:lanis/applets/substitutions/substitutions_view.dart';
import 'package:lanis/applets/timetable/student/student_timetable_better_view.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/startup.dart';
import 'package:lanis/utils/auth_controller.dart';
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

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

bool _isSupportedHomePath(Ref ref, String loc) {
  final idx = homeAppletPaths.indexWhere(
    (p) => loc == p || loc.startsWith('$p/'),
  );
  if (idx < 0) return true;
  return ref
      .read(supportedAppletPhpUrlsProvider)
      .contains(homeAppletPhpUrls[idx]);
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Do not watch auth here — recreating GoRouter resets the navigation stack.
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

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
          if (loc.startsWith('/storage') &&
              !supported.contains('dateispeicher.php')) {
            return firstSupportedHomePathFromRef(ref);
          }
          if (loc.startsWith('/study-groups') &&
              !supported.contains('lerngruppen.php')) {
            return firstSupportedHomePathFromRef(ref);
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
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/substitutions',
                builder: (context, state) => SubstitutionsView(
                  openDrawerCb: () => Scaffold.of(context).openDrawer(),
                ),
                routes: [
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/calendar',
                builder: (context, state) => CalendarView(
                  openDrawerCb: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/timetable',
                builder: (context, state) => StudentTimetableBetterView(
                  openDrawerCb: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/conversations',
                builder: (context, state) => ConversationsView(
                  openDrawerCb: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/lessons',
                builder: (context, state) {
                  return Consumer(
                    builder: (context, ref, _) {
                      final accountType = ref.watch(
                        activeAccountProvider.select((a) => a?.accountType),
                      );
                      final openDrawer = () =>
                          Scaffold.of(context).openDrawer();
                      if (accountType == AccountType.teacher) {
                        return LessonsTeacherView(
                          key: const ValueKey('lessons-teacher'),
                          openDrawerCb: openDrawer,
                        );
                      }
                      return LessonsStudentView(
                        key: const ValueKey('lessons-student'),
                        openDrawerCb: openDrawer,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/storage',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DataStorageRootView(),
      ),
      GoRoute(
        path: '/study-groups',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const StudentStudyGroupsView(),
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
