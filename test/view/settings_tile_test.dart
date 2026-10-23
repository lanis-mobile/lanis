import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/view/settings/settings.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  Future<void> renderTile(
    WidgetTester tester, {
    bool failShow = false,
    bool failSubtitle = false,
    bool visible = true,
  }) async {
    await pumpTestApp(
      tester,
      child: Scaffold(
        body: SettingsTileWidget(
          tile: SettingsTile(
            title: (_) => 'Test setting',
            subtitle: (_) async {
              if (failSubtitle) throw StateError('subtitle failed');
              return 'Stored value';
            },
            show: () async {
              if (failShow) throw StateError('visibility failed');
              return visible;
            },
            icon: Icons.settings,
            screen: (_) async {},
          ),
          index: 0,
          length: 1,
          foregroundColor: Colors.white,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final input in ['visibility', 'subtitle']) {
    testWidgets('failed $input future renders error without null crash', (
      tester,
    ) async {
      await renderTile(
        tester,
        failShow: input == 'visibility',
        failSubtitle: input == 'subtitle',
      );
      expect(tester.takeException(), isNull);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsTileWidget)),
      );
      expect(find.text(l10n.error), findsOneWidget);
    });
  }

  testWidgets('successful tile still renders its subtitle', (tester) async {
    await renderTile(tester);
    expect(find.text('Test setting'), findsOneWidget);
    expect(find.text('Stored value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden tile remains hidden', (tester) async {
    await renderTile(tester, visible: false);
    expect(find.text('Test setting'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
