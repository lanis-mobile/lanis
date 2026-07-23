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

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/startup',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggingIn = loc == '/welcome' || loc == '/login';
      final onStartup = loc == '/startup';

      switch (auth.phase) {
        case AuthPhase.authenticating:
          return onStartup ? null : '/startup';
        case AuthPhase.unauthenticated:
          if (loggingIn || onStartup) {
            // Allow startup briefly then send to welcome
            if (onStartup) return '/welcome';
            return null;
          }
          return '/welcome';
        case AuthPhase.error:
          return onStartup ? null : '/startup';
        case AuthPhase.authenticated:
          if (loggingIn || onStartup) return '/home/substitutions';
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
                  final account = ProviderScope.containerOf(context).read(
                    activeAccountProvider,
                  );
                  final openDrawer = () => Scaffold.of(context).openDrawer();
                  if (account?.accountType == AccountType.teacher) {
                    return LessonsTeacherView(openDrawerCb: openDrawer);
                  }
                  return LessonsStudentView(openDrawerCb: openDrawer);
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
