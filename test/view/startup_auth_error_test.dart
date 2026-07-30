import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/startup.dart';

import '../helpers/test_app.dart';

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
