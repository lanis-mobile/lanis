import 'package:material_ui/material_ui.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  final originalLauncher = launchUrlImpl;
  final uri = Uri.parse('https://example.com');

  tearDown(() {
    launchUrlImpl = originalLauncher;
  });

  test('returns false when the launcher throws and does not rethrow', () async {
    launchUrlImpl =
        (url, {LaunchMode mode = LaunchMode.platformDefault}) async {
          throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
        };

    expect(await safeLaunchUrl(uri), isFalse);
  });

  test('returns false when the launcher reports failure', () async {
    launchUrlImpl =
        (url, {LaunchMode mode = LaunchMode.platformDefault}) async {
          return false;
        };

    expect(await safeLaunchUrl(uri), isFalse);
  });

  for (final localized in [true, false]) {
    testWidgets(
      'failure snackbar uses ${localized ? 'German localization' : 'English fallback without app localizations'}',
      (tester) async {
        launchUrlImpl = (
          url, {
          LaunchMode mode = LaunchMode.platformDefault,
        }) async => false;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('de'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              if (localized) AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => safeLaunchUrl(uri, context: context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pump();
        expect(
          find.text(
            localized
                ? 'Dieser Link konnte nicht geöffnet werden.'
                : 'Could not open this link.',
          ),
          findsOneWidget,
        );
      },
    );
  }

  test('returns true when the launcher succeeds', () async {
    launchUrlImpl =
        (url, {LaunchMode mode = LaunchMode.platformDefault}) async {
          return true;
        };

    expect(await safeLaunchUrl(uri), isTrue);
  });
}
