import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/startup.dart';
import 'package:lanis/view/account_switcher/account_switcher.dart';
import 'package:lanis/widgets/reset_account_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_app.dart';

const _savedAccount = ClearTextAccount(
  localId: 1,
  schoolID: 1,
  username: 'demo',
  password: 'test',
  schoolName: 'Example School',
);

void main() {
  tearDown(resetAuthTestSeams);

  testWidgets('offline chrome shows wifi_off and offline title', (tester) async {
    await pumpTestApp(
      tester,
      child: StartupAuthErrorContent(
        exception: NoConnectionException(),
        onRetry: () {},
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StartupAuthErrorContent)),
    );
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.byIcon(Icons.wifi_find_outlined), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.text(l10n.noInternetConnection2), findsOneWidget);
  });

  testWidgets('lanis-down chrome shows message and error icon', (tester) async {
    await pumpTestApp(
      tester,
      child: StartupAuthErrorContent(
        exception: LanisDownException(),
        onRetry: () {},
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StartupAuthErrorContent)),
    );
    expect(find.byIcon(Icons.error), findsOneWidget);
    expect(find.text(l10n.lanisDownError), findsOneWidget);
    expect(find.text(l10n.lanisDownErrorMessage), findsOneWidget);
  });

  testWidgets('generic error shows startupError detail', (tester) async {
    await pumpTestApp(
      tester,
      child: StartupAuthErrorContent(
        exception: UnknownException('boom'),
        onRetry: () {},
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StartupAuthErrorContent)),
    );
    expect(find.text(l10n.startupError), findsOneWidget);
    expect(find.textContaining('UnknownException'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('wrong credentials shows reset account button', (tester) async {
    await pumpTestApp(
      tester,
      child: StartupAuthErrorContent(
        exception: WrongCredentialsException(),
        account: _savedAccount,
        onRetry: () {},
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StartupAuthErrorContent)),
    );
    expect(find.text(l10n.resetAccount), findsOneWidget);
    expect(find.byIcon(Icons.lock_reset), findsOneWidget);
  });

  for (final (exception, message) in [
    (
      ParentAccountWithoutLearnersException(),
      (AppLocalizations l10n) => l10n.loginParentWithoutLearners,
    ),
    (
      AccountDisabledException(),
      (AppLocalizations l10n) => l10n.loginAccountDisabled,
    ),
    (
      PasswordChangeRequiredException(),
      (AppLocalizations l10n) => l10n.loginPasswordChangeRequired,
    ),
  ]) {
    testWidgets('shows localized copy for ${exception.runtimeType}', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        child: StartupAuthErrorContent(exception: exception, onRetry: () {}),
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(StartupAuthErrorContent)),
      );
      expect(find.text(message(l10n)), findsOneWidget);
      expect(
        find.textContaining(exception.runtimeType.toString()),
        findsNothing,
      );
      expect(find.text(l10n.resetAccount), findsNothing);
    });
  }

  for (final exception in [
    ParentAccountWithoutLearnersException(),
    AccountDisabledException(),
    PasswordChangeRequiredException(),
  ]) {
    testWidgets('opens removal-only reset for ${exception.runtimeType}', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        child: StartupAuthErrorContent(
          exception: exception,
          account: _savedAccount,
          onRetry: () {},
        ),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(StartupAuthErrorContent)),
      );

      await tester.tap(find.text(l10n.deleteAccount));
      await tester.pumpAndSettle();

      expect(find.byType(ResetAccountPage), findsOneWidget);
      expect(find.text(l10n.resetAccount), findsOneWidget);
      expect(find.text(l10n.deleteAccount), findsOneWidget);
      expect(find.text(l10n.changePassword), findsNothing);
      expect(find.text(l10n.wrongPassword), findsNothing);
      expect(find.text('demo'), findsOneWidget);
    });
  }

  testWidgets('saved first-password prompt offers portal, delete, and switch', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      child: StartupAuthErrorContent(
        exception: PasswordChangeRequiredException(),
        account: _savedAccount,
        onRetry: () {},
        onOpenPortal: () {},
        onSwitchAccount: () {},
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(StartupAuthErrorContent)),
    );
    expect(find.widgetWithText(FilledButton, l10n.openSchulportalHessen), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, l10n.deleteAccount), findsOneWidget);
    expect(find.widgetWithText(TextButton, l10n.switchAccount), findsOneWidget);
    expect(find.text(l10n.changePassword), findsNothing);
  });

  testWidgets('retry icon invokes callback', (tester) async {
    var retried = false;
    await pumpTestApp(
      tester,
      child: StartupAuthErrorContent(
        exception: NoConnectionException(),
        onRetry: () => retried = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.refresh));
    expect(retried, isTrue);
  });

  testWidgets('deleting A closes its reset page before B fails on startup', (
    tester,
  ) async {
    final (container, idA, idB) = await _openStartup(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(StartupAuthErrorContent)),
    );
    expect(find.text(l10n.loginAccountDisabled), findsOneWidget);

    await tester.tap(find.text(l10n.deleteAccount));
    await _finishTransition(tester);
    expect(find.byType(ResetAccountPage), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);

    await tester.tap(find.text(l10n.deleteAccount));
    await _finishTransition(tester);

    expect(find.byType(ResetAccountPage), findsNothing);
    expect(find.text(l10n.loginParentWithoutLearners), findsOneWidget);
    expect(container.read(activeAccountProvider)?.localId, idB);
    final remaining = await container.read(accountsProvider.future);
    expect(remaining.map((account) => account.localId), [idB]);
    expect(remaining.any((account) => account.localId == idA), isFalse);

    // The next account requires opening a new page and confirming again.
    await tester.tap(find.text(l10n.deleteAccount));
    await _finishTransition(tester);
    expect(find.text('beta'), findsOneWidget);
    expect(await container.read(accountsProvider.future), hasLength(1));
  });

  for (final restoreSucceeds in [true, false]) {
    testWidgets(
      'switch reports the attempted error when restoration '
      '${restoreSucceeds ? 'succeeds' : 'fails'}',
      (tester) async {
        final (container, idA, _) = await _openStartup(
          tester,
          restoreSucceeds: restoreSucceeds,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(StartupAuthErrorContent)),
        );
        await tester.tap(find.text(l10n.switchAccount));
        await _finishTransition(tester);
        expect(find.byType(AccountSwitcher), findsOneWidget);
        expect(find.byType(StartupAuthErrorContent), findsNothing);

        await tester.tap(find.textContaining('beta ('));
        await _finishTransition(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(l10n.loginParentWithoutLearners), findsOneWidget);
        expect(container.read(activeAccountProvider)?.localId, idA);
        expect(
          container.read(authControllerProvider).phase,
          restoreSucceeds ? AuthPhase.authenticated : AuthPhase.error,
        );
        await tester.tap(find.text(l10n.close));
        await _finishTransition(tester);

        GoRouter.of(tester.element(find.byType(AccountSwitcher))).pop();
        await _finishTransition(tester);
        if (restoreSucceeds) {
          expect(find.text('Home destination'), findsOneWidget);
        } else {
          expect(find.text(l10n.loginPasswordChangeRequired), findsOneWidget);
          expect(find.text(l10n.loginAccountDisabled), findsNothing);
        }
      },
    );
  }
}

Future<(ProviderContainer, int, int)> _openStartup(
  WidgetTester tester, {
  bool restoreSucceeds = false,
}) async {
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(permissions, (_) async => <int, int>{17: 1});
  addTearDown(() => messenger.setMockMethodCallHandler(permissions, null));
  PackageInfo.setMockInitialValues(
    appName: 'Lanis',
    packageName: 'lanis',
    version: '4.4.0',
    buildNumber: '98',
    buildSignature: '',
    installerStore: null,
  );
  final container = await pumpTestRouterApp(
    tester,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => TextButton(
          onPressed: () => context.go('/startup'),
          child: const Text('Start'),
        ),
      ),
      GoRoute(path: '/startup', builder: (_, _) => const StartupScreen()),
      GoRoute(path: '/accounts', builder: (_, _) => const AccountSwitcher()),
      GoRoute(
        path: firstSupportedHomePathFor(
          supported: const {},
          accountType: AccountType.student,
        ),
        builder: (_, _) => const Text('Home destination'),
      ),
    ],
  );
  acceptPrivacy(container);
  final idA = await addTestAccount(container, username: 'alpha');
  final idB = await addTestAccount(container, schoolId: 2, username: 'beta');
  var firstLogin = true;
  AuthController.debugAuthenticate = (ref) async {
    if (ref.read(activeAccountProvider)?.localId == idB) {
      throw ParentAccountWithoutLearnersException();
    }
    if (firstLogin) {
      firstLogin = false;
      throw AccountDisabledException();
    }
    if (!restoreSucceeds) throw PasswordChangeRequiredException();
  };
  await container.read(authControllerProvider.notifier).loginWithAccount(idA);
  await tester.tap(find.text('Start'));
  await _finishTransition(tester);
  return (container, idA, idB);
}

Future<void> _finishTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
