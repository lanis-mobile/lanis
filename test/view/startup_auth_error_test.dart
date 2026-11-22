import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/startup.dart';
import 'package:lanis/widgets/reset_account_page.dart';

import '../helpers/test_app.dart';

class _SavedAccount extends ActiveAccount {
  @override
  ClearTextAccount build() => const ClearTextAccount(
    localId: 1,
    schoolID: 1,
    username: 'demo',
    password: 'test',
    schoolName: 'Example School',
  );
}

void main() {
  tearDown(LanisClient.reset);

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
        child: StartupAuthErrorContent(exception: exception, onRetry: () {}),
        overrides: [activeAccountProvider.overrideWith(_SavedAccount.new)],
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
}
