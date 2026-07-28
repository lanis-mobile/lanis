import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/calendar/calendar_export.dart';
import 'package:lanis/applets/timetable/student/student_timetable_settings.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/view/settings/settings.dart';
import 'package:lanis/view/settings/subsettings/about.dart';
import 'package:lanis/view/settings/subsettings/appearance.dart';
import 'package:lanis/view/settings/subsettings/cache.dart';
import 'package:lanis/view/settings/subsettings/error_reporting.dart';
import 'package:lanis/view/settings/subsettings/notifications.dart';
import 'package:lanis/view/settings/subsettings/userdata.dart';
import 'package:liblanis/liblanis.dart';

Widget _settingsDetail({
  required String fallbackPath,
  required Widget child,
}) {
  return DeepLinkPopScope(fallbackPath: fallbackPath, child: child);
}

/// Settings shell routes under `/common/settings`.
List<RouteBase> buildSettingsRoutes() {
  return [
    ShellRoute(
      builder: (context, state, child) {
        if (Responsive.isTablet(context)) {
          return SettingsTabletShell(child: child);
        }
        return child;
      },
      routes: [
        GoRoute(
          path: SettingsDeepLinks.base,
          redirect: (context, state) {
            final path = state.uri.path;
            // Tablet master–detail: land on the first setting so the detail
            // pane is never an empty white panel.
            if (path == SettingsDeepLinks.base ||
                path == SettingsDeepLinks.home) {
              if (Responsive.isTablet(context)) {
                return SettingsDeepLinks.appearance;
              }
            }
            if (path == SettingsDeepLinks.base) {
              return SettingsDeepLinks.home;
            }
            return null;
          },
          routes: [
            GoRoute(
              path: 'home',
              builder: (context, state) {
                if (Responsive.isTablet(context)) {
                  return const SizedBox.shrink();
                }
                return const SettingsScreen();
              },
            ),
            GoRoute(
              path: 'appearance',
              builder: (context, state) => _settingsDetail(
                fallbackPath: SettingsDeepLinks.home,
                child: const AppearanceSettings(),
              ),
            ),
            GoRoute(
              path: 'notifications',
              builder: (context, state) => _settingsDetail(
                fallbackPath: SettingsDeepLinks.home,
                child: Consumer(
                  builder: (context, ref, _) {
                    final count =
                        ref.watch(accountsProvider).asData?.value.length ?? 0;
                    return NotificationSettings(accountCount: count);
                  },
                ),
              ),
            ),
            GoRoute(
              path: 'cache',
              builder: (context, state) => _settingsDetail(
                fallbackPath: SettingsDeepLinks.home,
                child: const CacheSettings(),
              ),
            ),
            GoRoute(
              path: 'userdata',
              builder: (context, state) => _settingsDetail(
                fallbackPath: SettingsDeepLinks.home,
                child: const UserDataSettings(),
              ),
            ),
            GoRoute(
              path: 'error-reporting',
              builder: (context, state) => _settingsDetail(
                fallbackPath: SettingsDeepLinks.home,
                child: const ErrorReportingSettings(),
              ),
            ),
            GoRoute(
              path: 'about',
              builder: (context, state) => _settingsDetail(
                fallbackPath: SettingsDeepLinks.home,
                child: const AboutSettings(),
              ),
            ),
            GoRoute(
              path: 'calendar-export',
              builder: (context, state) => _settingsDetail(
                fallbackPath: SettingsDeepLinks.home,
                child: const CalendarExport(),
              ),
              routes: [
                GoRoute(
                  path: ':kind',
                  builder: (context, state) => _settingsDetail(
                    fallbackPath: SettingsDeepLinks.calendarExport,
                    child: const CalendarExport(),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'timetable',
              builder: (context, state) => _settingsDetail(
                fallbackPath: SettingsDeepLinks.home,
                child: const StudentTimetableSettings(),
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}

/// Tablet master–detail: settings list beside the matched child route.
class SettingsTabletShell extends StatelessWidget {
  final Widget child;

  const SettingsTabletShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final onHome = loc == SettingsDeepLinks.home || loc == SettingsDeepLinks.base;

    // Resize phone→tablet while on /home does not re-run go_router redirects.
    if (onHome) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final path = GoRouterState.of(context).uri.path;
        if (path == SettingsDeepLinks.home || path == SettingsDeepLinks.base) {
          // Defer past any navigator lock from the resize layout pass.
          Future<void>(() {
            if (!context.mounted) return;
            final latest = GoRouterState.of(context).uri.path;
            if (latest == SettingsDeepLinks.home ||
                latest == SettingsDeepLinks.base) {
              context.go(SettingsDeepLinks.appearance);
            }
          });
        }
      });
    }

    return Scaffold(
      body: Row(
        children: [
          const SizedBox(
            width: 300,
            child: SettingsScreen(embeddedInTabletShell: true),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: onHome
                ? const SizedBox.shrink()
                : child,
          ),
        ],
      ),
    );
  }
}
