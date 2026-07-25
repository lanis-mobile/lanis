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
import 'package:lanis/view/settings/subsettings/notifications.dart';
import 'package:lanis/view/settings/subsettings/userdata.dart';
import 'package:liblanis/liblanis.dart';

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
            if (state.uri.path == SettingsDeepLinks.base) {
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
              builder: (context, state) => AppearanceSettings(
                showBackButton: !Responsive.isTablet(context),
              ),
            ),
            GoRoute(
              path: 'notifications',
              builder: (context, state) => Consumer(
                builder: (context, ref, _) {
                  final count =
                      ref.watch(accountsProvider).asData?.value.length ?? 0;
                  return NotificationSettings(
                    accountCount: count,
                    showBackButton: !Responsive.isTablet(context),
                  );
                },
              ),
            ),
            GoRoute(
              path: 'cache',
              builder: (context, state) => CacheSettings(
                showBackButton: !Responsive.isTablet(context),
              ),
            ),
            GoRoute(
              path: 'userdata',
              builder: (context, state) => UserDataSettings(
                showBackButton: !Responsive.isTablet(context),
              ),
            ),
            GoRoute(
              path: 'about',
              builder: (context, state) =>
                  AboutSettings(showBackButton: !Responsive.isTablet(context)),
            ),
            GoRoute(
              path: 'calendar-export',
              builder: (context, state) => CalendarExport(
                showBackButton: !Responsive.isTablet(context),
              ),
              routes: [
                GoRoute(
                  path: ':kind',
                  builder: (context, state) {
                    return DeepLinkPopScope(
                      fallbackPath: SettingsDeepLinks.calendarExport,
                      child: CalendarExport(
                        showBackButton: !Responsive.isTablet(context),
                      ),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'timetable',
              builder: (context, state) => StudentTimetableSettings(
                showBack: !Responsive.isTablet(context),
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
