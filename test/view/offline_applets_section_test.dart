import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/startup.dart';
import 'package:lanis/widgets/offline_available_applets_section.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(resetAuthTestSeams);

  testWidgets('empty offline list shows no tiles', (tester) async {
    await pumpTestApp(
      tester,
      child: const Scaffold(body: OfflineAvailableAppletsSection()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('seeded offline data lists applet with school name', (tester) async {
    final overrides = testLanisOverrides();
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    final id = await addTestAccount(
      container,
      schoolName: 'Alone School',
      username: 'solo',
    );
    container.read(lanisDatabaseProvider).setAppletOfflineData(
      accountId: id,
      appletId: 'vertretungsplan.php',
      json: '{"days":[]}',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: const Scaffold(body: OfflineAvailableAppletsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Alone School'), findsOneWidget);
  });

  testWidgets('multi-account subtitle includes username', (tester) async {
    final overrides = testLanisOverrides();
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    final idA = await addTestAccount(
      container,
      schoolName: 'School A',
      username: 'alice',
    );
    await addTestAccount(
      container,
      schoolId: 2,
      schoolName: 'School B',
      username: 'bob',
    );
    container.read(lanisDatabaseProvider).setAppletOfflineData(
      accountId: idA,
      appletId: 'vertretungsplan.php',
      json: '{}',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: const Scaffold(body: OfflineAvailableAppletsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('School A (alice)'), findsOneWidget);
  });

  test('offline open selects account without network authenticate', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    final id = await addTestAccount(container);
    container.read(lanisDatabaseProvider).setAppletOfflineData(
      accountId: id,
      appletId: 'vertretungsplan.php',
      json: '{}',
    );

    final before = AuthController.authenticateCallCount;
    await container.read(activeAccountProvider.notifier).select(id);
    expect(container.read(activeAccountProvider)?.localId, id);
    expect(AuthController.authenticateCallCount, before);
  });

  testWidgets('startup error content includes offline section for lanis-down',
      (tester) async {
    await pumpTestApp(
      tester,
      child: StartupAuthErrorContent(
        exception: LanisDownException(),
        onRetry: () {},
      ),
    );
    expect(find.byType(OfflineAvailableAppletsSection), findsOneWidget);
  });

  testWidgets('startup error content includes offline section for generic error',
      (tester) async {
    await pumpTestApp(
      tester,
      child: StartupAuthErrorContent(
        exception: UnknownException('x'),
        onRetry: () {},
      ),
    );
    expect(find.byType(OfflineAvailableAppletsSection), findsOneWidget);
  });
}
