import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/shell_navigation.dart';
import 'package:lanis/utils/applet_navigation_order.dart';

import '../helpers/test_app.dart';

AppletDefinition _bySegment(String segment) =>
    AppDefinitions.applets.firstWhere((a) => a.pathSegment == segment);

void main() {
  tearDown(resetAuthTestSeams);

  group('AppletNavigationLayout normalization', () {
    test('defaults match AppDefinitions.homeApplets and navigationApplets', () {
      final layout = AppletNavigationLayout.defaults();
      expect(
        layout.bottomBar.map((a) => a.pathSegment),
        AppDefinitions.homeApplets.map((a) => a.pathSegment),
      );
      expect(
        layout.drawer.map((a) => a.pathSegment),
        AppDefinitions.navigationApplets.map((a) => a.pathSegment),
      );
    });

    test('fromJson drops unknown/duplicate segments and caps bottomBar at 5', () {
      final layout = AppletNavigationLayout.fromJson({
        'bottomBar': [
          'storage',
          'unknown-applet',
          'calendar',
          'storage',
          'timetable',
          'conversations',
          'lessons',
          'substitutions',
        ],
        'drawer': ['file-distribution', 'calendar', 'nope'],
      });

      expect(layout.bottomBar.map((a) => a.pathSegment).toList(), [
        'storage',
        'calendar',
        'timetable',
        'conversations',
        'lessons',
      ]);
      // Excess bottomBar item ('substitutions') goes to top of drawer;
      // missing applet ('study-groups') is appended.
      expect(layout.drawer.map((a) => a.pathSegment).toList(), [
        'substitutions',
        'file-distribution',
        'study-groups',
      ]);
    });

    test('fromJson preserves intentionally empty bottomBar', () {
      final layout = AppletNavigationLayout.fromJson({
        'bottomBar': <String>[],
        'drawer': AppDefinitions.applets.map((a) => a.pathSegment).toList(),
      });

      expect(layout.bottomBar, isEmpty);
      expect(layout.drawer.length, AppDefinitions.applets.length);
    });

    test('fromJson falls back to defaults for malformed JSON', () {
      final layout = AppletNavigationLayout.fromJson({
        'bottomBar': 'invalid',
        'drawer': 42,
      });
      expect(layout, AppletNavigationLayout.defaults());
    });

    test(
      'withVisibleSections lets partial-support accounts fill all 5 bottom-bar slots',
      () {
        final teacherSupported = {
          'vertretungsplan.php',
          'kalender.php',
          'nachrichten.php',
          'dateispeicher.php',
          'dateiverteilung.php',
        };
        final defaults = AppletNavigationLayout.defaults();
        final visibleBottom = defaults.supportedBottomBar(
          supportedPhpUrls: teacherSupported,
          accountType: AccountType.teacher,
        );
        final visibleDrawer = defaults.supportedDrawer(
          supportedPhpUrls: teacherSupported,
          accountType: AccountType.teacher,
        );
        expect(visibleBottom.length, 3);
        expect(visibleDrawer.length, 2);

        // Move both drawer applets into bottom bar (5 supported total).
        final updated = defaults.withVisibleSections(
          visibleBottomBar: [...visibleBottom, ...visibleDrawer],
          visibleDrawer: const [],
        );

        expect(
          updated
              .supportedBottomBar(
                supportedPhpUrls: teacherSupported,
                accountType: AccountType.teacher,
              )
              .map((a) => a.pathSegment)
              .toList(),
          [
            'substitutions',
            'calendar',
            'conversations',
            'storage',
            'file-distribution',
          ],
        );
        // Unsupported applets remain preserved in drawer without taking bottom slots.
        expect(updated.all.length, AppDefinitions.applets.length);
        expect(
          updated.drawer.map((a) => a.pathSegment).toSet(),
          {'timetable', 'lessons', 'study-groups'},
        );
      },
    );
  });

  group('reorderAppletSections', () {
    final bottom5 = [
      _bySegment('substitutions'),
      _bySegment('calendar'),
      _bySegment('timetable'),
      _bySegment('conversations'),
      _bySegment('lessons'),
    ];
    final drawer3 = [
      _bySegment('storage'),
      _bySegment('file-distribution'),
      _bySegment('study-groups'),
    ];

    test('reorders within bottom bar', () {
      // Flat: [H0, sub(1), cal(2), tt(3), conv(4), les(5), H1(6), st(7), fd(8), sg(9)]
      // onReorderItem passes post-removal index 3 (after tt).
      final res = reorderAppletSections(
        bottomBar: bottom5,
        drawer: drawer3,
        oldIndex: 1,
        newIndex: 3,
      );
      expect(res.bumpedToDrawer, isNull);
      expect(res.bottomBar.map((a) => a.pathSegment).toList(), [
        'calendar',
        'timetable',
        'substitutions',
        'conversations',
        'lessons',
      ]);
      expect(
        res.drawer.map((a) => a.pathSegment).toList(),
        drawer3.map((a) => a.pathSegment).toList(),
      );
    });

    test('moves bottom-bar item down into drawer', () {
      // Drag lessons (5) below H1: post-removal H1 is at 5, so insert at 6.
      final res = reorderAppletSections(
        bottomBar: bottom5,
        drawer: drawer3,
        oldIndex: 5,
        newIndex: 6,
      );
      expect(res.bumpedToDrawer, isNull);
      expect(res.bottomBar.map((a) => a.pathSegment).toList(), [
        'substitutions',
        'calendar',
        'timetable',
        'conversations',
      ]);
      expect(res.drawer.map((a) => a.pathSegment).toList(), [
        'lessons',
        'storage',
        'file-distribution',
        'study-groups',
      ]);
    });

    test('dragging drawer item into full bottom bar bumps last item to drawer', () {
      // Drag storage (7) between substitutions (1) and calendar (2).
      final res = reorderAppletSections(
        bottomBar: bottom5,
        drawer: drawer3,
        oldIndex: 7,
        newIndex: 2,
      );
      expect(res.bumpedToDrawer?.pathSegment, 'lessons');
      expect(res.bottomBar.map((a) => a.pathSegment).toList(), [
        'substitutions',
        'storage',
        'calendar',
        'timetable',
        'conversations',
      ]);
      expect(res.drawer.map((a) => a.pathSegment).toList(), [
        'lessons',
        'file-distribution',
        'study-groups',
      ]);
    });

    test(
      'dragging drawer item to end of full bottom bar replaces 5th slot and bumps old 5th',
      () {
        // Drag storage (7) right above H1 (6).
        final res = reorderAppletSections(
          bottomBar: bottom5,
          drawer: drawer3,
          oldIndex: 7,
          newIndex: 6,
        );
        expect(res.bumpedToDrawer?.pathSegment, 'lessons');
        expect(res.bottomBar.map((a) => a.pathSegment).toList(), [
          'substitutions',
          'calendar',
          'timetable',
          'conversations',
          'storage',
        ]);
        expect(res.drawer.map((a) => a.pathSegment).toList(), [
          'lessons',
          'file-distribution',
          'study-groups',
        ]);
      },
    );

    test('dragging above top header clamps to first bottom-bar slot', () {
      final res = reorderAppletSections(
        bottomBar: bottom5,
        drawer: drawer3,
        oldIndex: 7,
        newIndex: 0,
      );
      expect(res.bottomBar.first.pathSegment, 'storage');
      expect(res.bottomBar.length, 5);
      expect(res.drawer.first.pathSegment, 'lessons');
    });

    test('moveAppletToDrawer and moveAppletToBottomBar enforce max 5', () {
      final fullAttempt = moveAppletToBottomBar(
        bottomBar: bottom5,
        drawer: drawer3,
        def: _bySegment('storage'),
      );
      expect(fullAttempt.bottomBar.length, 5);

      final demoted = moveAppletToDrawer(
        bottomBar: bottom5,
        drawer: drawer3,
        def: _bySegment('calendar'),
      );
      expect(demoted.bottomBar.length, 4);
      expect(demoted.drawer.first.pathSegment, 'calendar');

      final promoted = moveAppletToBottomBar(
        bottomBar: demoted.bottomBar,
        drawer: demoted.drawer,
        def: _bySegment('storage'),
      );
      expect(promoted.bottomBar.last.pathSegment, 'storage');
      expect(promoted.bottomBar.length, 5);
    });
  });

  group('per-account persistence & firstSupportedHomePathFor', () {
    test('appletNavigationLayoutProvider isolates order per account', () async {
      final container = ProviderContainer(overrides: testLanisOverrides());
      addTearDown(container.dispose);

      final accountA = await addTestAccount(
        container,
        username: 'alice',
        accountType: AccountType.student,
      );
      final accountB = await addTestAccount(
        container,
        username: 'bob',
        accountType: AccountType.student,
      );

      // Customize Account A.
      await container.read(activeAccountProvider.notifier).select(accountA);
      final settingsA = container.read(accountSpecificSettingsProvider)!;
      final customA = AppletNavigationLayout.fromJson({
        'bottomBar': ['storage', 'conversations', 'calendar'],
        'drawer': [
          'substitutions',
          'timetable',
          'lessons',
          'file-distribution',
          'study-groups',
        ],
      });
      settingsA.setJsonMap(appletNavigationOrderSettingsKey, customA.toJson());
      container.read(appletNavigationOrderRevisionProvider.notifier).bump();

      expect(
        container
            .read(appletNavigationLayoutProvider)
            .bottomBar
            .map((a) => a.pathSegment)
            .toList(),
        ['storage', 'conversations', 'calendar'],
      );

      // Account B still has default order.
      await container.read(activeAccountProvider.notifier).select(accountB);
      expect(
        container.read(appletNavigationLayoutProvider),
        AppletNavigationLayout.defaults(),
      );

      // Switching back to Account A restores A's custom order.
      await container.read(activeAccountProvider.notifier).select(accountA);
      expect(
        container
            .read(appletNavigationLayoutProvider)
            .bottomBar
            .map((a) => a.pathSegment)
            .toList(),
        ['storage', 'conversations', 'calendar'],
      );
    });

    test('firstSupportedHomePathFor respects custom layout order', () {
      final layout = AppletNavigationLayout.fromJson({
        'bottomBar': ['storage', 'conversations'],
        'drawer': ['substitutions', 'calendar'],
      });

      final path = firstSupportedHomePathFor(
        supported: {'vertretungsplan.php', 'dateispeicher.php'},
        accountType: AccountType.student,
        layout: layout,
      );
      expect(
        path,
        appletHomePath(_bySegment('storage'), AccountType.student),
      );
    });

    test(
      'firstSupportedHomePathFor falls back to drawer applets when bottomBar is empty',
      () {
        final layout = AppletNavigationLayout.fromJson({
          'bottomBar': <String>[],
          'drawer': ['file-distribution', 'calendar'],
        });

        final path = firstSupportedHomePathFor(
          supported: {'dateiverteilung.php', 'kalender.php'},
          accountType: AccountType.student,
          layout: layout,
        );
        expect(
          path,
          appletHomePath(_bySegment('file-distribution'), AccountType.student),
        );
      },
    );
  });
}
