import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/view/login/auth.dart';
import 'package:lanis/view/login/school_selector.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  setUp(() {
    SchoolSelector.skipNetworkLoad = true;
  });

  tearDown(() {
    SchoolSelector.skipNetworkLoad = false;
  });

  testWidgets('login button disabled until privacy checkbox accepted', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      child: const Scaffold(body: LoginForm(showBackButton: false)),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(LoginForm)),
    );
    expect(find.text(l10n.logIn), findsWidgets);

    final filled = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(filled.onPressed, isNull);
  });

  testWidgets('username and password fields disabled without school id', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      child: const Scaffold(body: LoginForm(showBackButton: false)),
    );

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.length, greaterThanOrEqualTo(2));
    for (final field in fields) {
      expect(field.enabled, isFalse);
    }
  });
}
