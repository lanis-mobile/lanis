import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/view/privacy_policy/privacy_policy_screen.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  testWidgets('shows title open and accept actions', (tester) async {
    await pumpTestApp(tester, child: const PrivacyPolicyScreen());

    final l10n = AppLocalizations.of(
      tester.element(find.byType(PrivacyPolicyScreen)),
    );
    expect(find.text(l10n.privacyPolicyGateTitle), findsOneWidget);
    expect(find.text(l10n.privacyPolicyGateOpen), findsOneWidget);
    expect(find.text(l10n.privacyPolicyGateAccept), findsOneWidget);
  });

  testWidgets('accept writes shared settings and goes to welcome', (tester) async {
    final container = await pumpTestRouterApp(
      tester,
      initialLocation: '/privacy-policy',
      routes: [
        GoRoute(
          path: '/privacy-policy',
          builder: (_, _) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: '/welcome',
          builder: (_, _) => const Scaffold(body: Text('welcome-marker')),
        ),
      ],
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(PrivacyPolicyScreen)),
    );
    await tester.tap(find.text(l10n.privacyPolicyGateAccept));
    await tester.pumpAndSettle();

    final shared = container.read(sharedOverAccountSettingsProvider);
    expect(isPrivacyPolicyAccepted(shared), isTrue);
    expect(find.text('welcome-marker'), findsOneWidget);
  });
}
