import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/view/login/screen.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  testWidgets('welcome shows first page title', (tester) async {
    await pumpTestRouterApp(
      tester,
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (_, _) => const WelcomeLoginScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('login-marker')),
        ),
      ],
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(WelcomeLoginScreen)),
    );
    expect(find.text(l10n.introWelcomeTitle), findsOneWidget);
  });

  testWidgets('skip navigates to login', (tester) async {
    await pumpTestRouterApp(
      tester,
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (_, _) => const WelcomeLoginScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('login-marker')),
        ),
      ],
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(WelcomeLoginScreen)),
    );
    await tester.tap(find.text(l10n.introSkip));
    await tester.pumpAndSettle();
    expect(find.text('login-marker'), findsOneWidget);
  });
}
