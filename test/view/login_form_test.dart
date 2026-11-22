import 'package:material_ui/material_ui.dart';
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

  testWidgets('password starts hidden and can be revealed and hidden again', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      child: const Scaffold(body: LoginForm(showBackButton: false)),
    );

    final school = tester.widget<SchoolSelector>(find.byType(SchoolSelector));
    school.controller.text = '1';
    school.onSchoolSelected('Example School');
    await tester.pump();

    final context = tester.element(find.byType(LoginForm));
    final l10n = AppLocalizations.of(context);
    final state = tester.state<LoginFormState>(find.byType(LoginForm));
    final field = find.byWidgetPredicate(
      (widget) =>
          widget is EditableText && widget.controller == state.passwordController,
    );
    await tester.enterText(field, 'example-password');
    expect(tester.widget<EditableText>(field).obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.showPassword));
    await tester.pump();
    expect(tester.widget<EditableText>(field).obscureText, isFalse);
    expect(find.byIcon(Icons.visibility), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.hidePassword));
    await tester.pump();
    expect(tester.widget<EditableText>(field).obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    expect(state.passwordController.text, 'example-password');
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
              supportedLocales: AppLocalizations.supportedLocales,
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
