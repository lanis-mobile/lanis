import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/shell_navigation.dart';
import 'package:lanis/utils/applet_navigation_order.dart';
import 'package:lanis/view/settings/subsettings/navigation.dart';
import 'package:lanis/widgets/applet_home_shell.dart';

import '../helpers/test_app.dart';

const _allStudentPhpUrls = {
  'vertretungsplan.php',
  'kalender.php',
  'stundenplan.php',
  'nachrichten.php',
  'meinunterricht.php',
  'dateispeicher.php',
  'dateiverteilung.php',
  'lerngruppen.php',
};

void main() {
  tearDown(resetAuthTestSeams);

  testWidgets(
    'NavigationSettings moves applets between bottom bar and sidebar and resets',
    (tester) async {
      final container = await pumpTestApp(
        tester,
        overrides: [
          supportedAppletPhpUrlsProvider.overrideWith(
            (ref) => _allStudentPhpUrls,
          ),
        ],
        child: const NavigationSettings(),
      );
      final id = await addTestAccount(
        container,
        accountType: AccountType.student,
      );
      await container.read(activeAccountProvider.notifier).select(id);
      await tester.pumpAndSettle();

      // Initially 5/5 in bottom bar; reset button disabled.
      expect(find.text('5/5'), findsOneWidget);
      final resetFinder = find.widgetWithText(
        OutlinedButton,
        'Reset to default',
      );
      await tester.scrollUntilVisible(resetFinder, 200);
      expect(tester.widget<OutlinedButton>(resetFinder).onPressed, isNull);

      // Scroll back to top and move first bottom-bar applet (Substitutions) to sidebar.
      await tester.scrollUntilVisible(find.text('Bottom bar'), -200);
      final moveToSidebarButtons = find.byTooltip('Move to sidebar');
      expect(moveToSidebarButtons, findsNWidgets(5));
      await tester.tap(moveToSidebarButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('4/5'), findsOneWidget);
      var layout = container.read(appletNavigationLayoutProvider);
      expect(layout.bottomBar.map((a) => a.pathSegment).toList(), [
        'calendar',
        'timetable',
        'conversations',
        'lessons',
      ]);
      expect(layout.drawer.first.pathSegment, 'substitutions');

      // Now promote Data Storage into the open 5th bottom-bar slot.
      final storageTile = find.byKey(const ValueKey('applet-storage'));
      await tester.scrollUntilVisible(storageTile, 200);
      await tester.tap(
        find.descendant(
          of: storageTile,
          matching: find.byTooltip('Move to bottom bar'),
        ),
      );
      await tester.pumpAndSettle();

      layout = container.read(appletNavigationLayoutProvider);
      expect(layout.bottomBar.map((a) => a.pathSegment).toList(), [
        'calendar',
        'timetable',
        'conversations',
        'lessons',
        'storage',
      ]);

      // Reset restores defaults.
      await tester.scrollUntilVisible(resetFinder, 200);
      expect(tester.widget<OutlinedButton>(resetFinder).onPressed, isNotNull);
      await tester.tap(resetFinder);
      await tester.pumpAndSettle();

      expect(
        container.read(appletNavigationLayoutProvider),
        AppletNavigationLayout.defaults(),
      );
    },
  );

  testWidgets('NavigationSettings supports dragging applets via drag handles', (
    tester,
  ) async {
    final container = await pumpTestApp(
      tester,
      overrides: [
        supportedAppletPhpUrlsProvider.overrideWith(
          (ref) => _allStudentPhpUrls,
        ),
      ],
      child: const NavigationSettings(),
    );
    final id = await addTestAccount(
      container,
      accountType: AccountType.student,
    );
    await container.read(activeAccountProvider.notifier).select(id);
    await tester.pumpAndSettle();

    // Drag Substitutions (first tile) down past Calendar (second tile).
    final subHandle = find.descendant(
      of: find.byKey(const ValueKey('applet-substitutions')),
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    final ttTile = find.byKey(const ValueKey('applet-timetable'));
    final start = tester.getCenter(subHandle);
    final end = tester.getCenter(ttTile);

    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(Offset(start.dx, end.dy));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    final layout = container.read(appletNavigationLayoutProvider);
    expect(layout.bottomBar.first.pathSegment, 'calendar');
    expect(
      layout.bottomBar.map((a) => a.pathSegment).toList(),
      contains('substitutions'),
    );
  });

  testWidgets(
    'HomePage phone bottom bar, drawer, and tablet rail honor custom order while keeping Open Moodle+ fixed',
    (tester) async {
      tester.view.physicalSize = const Size(420, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final branches = <StatefulShellBranch>[
        for (final def in [
          ...AppDefinitions.homeApplets,
          ...AppDefinitions.navigationApplets,
        ])
          StatefulShellBranch(
            routes: [
              appletHomeShell(
                homePath: def.homePath(AccountType.student),
                homeBuilder: (context, state) => Scaffold(
                  appBar: AppBar(title: Text('Page:${def.pathSegment}')),
                  body: Center(child: Text('Body:${def.pathSegment}')),
                ),
              ),
            ],
          ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/common/settings/home',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Settings')),
              ),
            ),
          ],
        ),
      ];

      final container = await pumpTestRouterApp(
        tester,
        initialLocation: '/common/storage/home',
        overrides: [
          supportedAppletPhpUrlsProvider.overrideWith(
            (ref) => _allStudentPhpUrls,
          ),
        ],
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => MediaQuery(
              // Flutter's square Ahem test font is wider than real UI fonts in
              // the 280px NavigationDrawer destination row.
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(0.75)),
              child: HomePage(navigationShell: shell),
            ),
            branches: branches,
          ),
        ],
      );

      final id = await addTestAccount(
        container,
        accountType: AccountType.student,
      );
      await container.read(activeAccountProvider.notifier).select(id);

      // Put Data Storage first and Calendar second in bottom bar; rest in drawer.
      container
          .read(appletNavigationLayoutProvider.notifier)
          .save(
            AppletNavigationLayout.fromJson({
              'bottomBar': ['storage', 'calendar'],
              'drawer': [
                'substitutions',
                'timetable',
                'conversations',
                'lessons',
                'file-distribution',
                'study-groups',
              ],
            }),
          );
      await tester.pumpAndSettle();

      // Phone bottom bar renders Storage first, Calendar second, with Storage selected.
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 2);
      expect(
        navBar.destinations
            .map((d) => (d as NavigationDestination).label)
            .toList(),
        ['Datastorage', 'Calendar'],
      );
      expect(navBar.selectedIndex, 0);
      expect(find.text('Body:storage'), findsOneWidget);

      // Tapping second destination routes to Calendar branch (branch index 1, not 1-by-coincidence:
      // storage is branch 5 and selectedIndex 0).
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(find.text('Body:calendar'), findsOneWidget);

      // Open drawer and verify custom order + fixed utility tail.
      final scaffoldState = tester.state<ScaffoldState>(
        find.byType(Scaffold).first,
      );
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final drawer = tester.widget<NavigationDrawer>(
        find.byType(NavigationDrawer),
      );
      final drawerDestinations = drawer.children
          .whereType<NavigationDrawerDestination>()
          .map((d) => (d.label as Text).data)
          .toList();
      expect(drawerDestinations, [
        'Datastorage',
        'Calendar',
        'Substitutions',
        'Timetable',
        'Messages',
        'Lessons',
        'File Distribution',
        'Study groups',
        'Open Moodle',
        'Open in Browser',
        'Settings',
        'Logout',
        'Server status',
      ]);

      // Navigating to a drawer-only applet (Substitutions) hides the phone bottom bar.
      await tester.tap(find.text('Substitutions'));
      await tester.pumpAndSettle();
      expect(find.text('Body:substitutions'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // Resize to tablet: NavigationRail shows all applets in custom order + Settings.
      tester.view.physicalSize = const Size(900, 900);
      await tester.pumpAndSettle();
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(
        rail.destinations.map((d) => (d.label as Text).data).toList(),
        [
          'Datastorage',
          'Calendar',
          'Substitutions',
          'Timetable',
          'Messages',
          'Lessons',
          'File Distribution',
          'Study groups',
          'Settings',
        ],
      );
      // Substitutions is index 2 in custom rail order.
      expect(rail.selectedIndex, 2);
      expect(
        shellBranchIndexForApplet(
          AppDefinitions.applets.firstWhere(
            (a) => a.pathSegment == 'substitutions',
          ),
        ),
        0,
      );
    },
  );

  testWidgets(
    'opening a sidebar-only applet via deep link hides phone bottom bar and system back returns to bottom-bar applet',
    (tester) async {
      tester.view.physicalSize = const Size(420, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final branches = <StatefulShellBranch>[
        for (final def in [
          ...AppDefinitions.homeApplets,
          ...AppDefinitions.navigationApplets,
        ])
          StatefulShellBranch(
            routes: [
              appletHomeShell(
                homePath: def.homePath(AccountType.student),
                homeBuilder: (context, state) => Scaffold(
                  appBar: AppBar(title: Text('Page:${def.pathSegment}')),
                  body: Center(child: Text('Body:${def.pathSegment}')),
                ),
              ),
            ],
          ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/common/settings/home',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Settings')),
              ),
            ),
          ],
        ),
      ];

      // Cold-open directly into Substitutions (simulating a notification tap).
      final container = await pumpTestRouterApp(
        tester,
        initialLocation: '/common/substitutions/home',
        overrides: [
          supportedAppletPhpUrlsProvider.overrideWith(
            (ref) => _allStudentPhpUrls,
          ),
        ],
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                HomePage(navigationShell: shell),
            branches: branches,
          ),
        ],
      );

      final id = await addTestAccount(
        container,
        accountType: AccountType.student,
      );
      await container.read(activeAccountProvider.notifier).select(id);
      container
          .read(appletNavigationLayoutProvider.notifier)
          .save(
            AppletNavigationLayout.fromJson({
              'bottomBar': ['storage', 'calendar'],
              'drawer': [
                'substitutions',
                'timetable',
                'conversations',
                'lessons',
                'file-distribution',
                'study-groups',
              ],
            }),
          );
      await tester.pumpAndSettle();

      // Substitutions is in the sidebar, so no bottom bar is shown.
      expect(find.text('Body:substitutions'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // System back navigates to the first bottom-bar applet (Datastorage).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Body:storage'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
}
