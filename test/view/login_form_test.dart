import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/glitchtip.dart';
import 'package:lanis/view/login/auth.dart';
import 'package:lanis/view/login/school_selector.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(() {
    LanisClient.reset();
    setGlitchTipReportingEnabled(false);
  });

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

  testWidgets('error reporting checkbox mirrors shared device setting', (
    tester,
  ) async {
    final overrides = LanisClient.configure();
    var seeded = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: Builder(
          builder: (context) {
            if (!seeded) {
              seeded = true;
              setGlitchTipEnabled(
                ProviderScope.containerOf(context)
                    .read(sharedOverAccountSettingsProvider),
                true,
              );
            }
            return MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              home: const Scaffold(
                body: LoginForm(showBackButton: false),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(LoginForm)),
    );
    final tiles = tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(tiles.length, greaterThanOrEqualTo(2));
    final errorTile = tiles.firstWhere(
      (t) =>
          t.title is Text &&
          (t.title as Text).data == l10n.authErrorReportingOptional,
    );
    expect(errorTile.value, isTrue);
  });
}
