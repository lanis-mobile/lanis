import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/l10n/locale_resolution.dart';

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);
  setUpAll(initializeDateFormatting);

  test('English remains the fallback for unsupported or absent locales', () {
    expect(AppLocalizations.supportedLocales.first, const Locale('en'));
    expect(
      resolveAppLocale([
        const Locale('fr', 'FR'),
      ], AppLocalizations.supportedLocales),
      const Locale('en'),
    );
    expect(
      resolveAppLocale(null, AppLocalizations.supportedLocales),
      const Locale('en'),
    );
  });

  test(
    'locale resolution keeps implicit number and date formatting in sync',
    () {
      final locales = AppLocalizations.supportedLocales;
      expect(
        resolveAppLocale([
          const Locale('fr'),
          const Locale('de', 'DE'),
        ], locales),
        const Locale('de'),
      );
      expect(NumberFormat.decimalPattern().format(1234.5), '1.234,5');
      expect(DateFormat.yMd().format(DateTime(2026, 11, 20)), '20.11.2026');
      resolveAppLocale([const Locale('en', 'US')], locales);
      expect(NumberFormat.decimalPattern().format(1234.5), '1,234.5');
      expect(DateFormat.yMd().format(DateTime(2026, 11, 20)), '11/20/2026');
    },
  );

  test('placeholder order, plural branches, selects and apostrophes survive generation', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    expect(
      en.dateTimeString('Friday', '20 November', '09:30'),
      'Friday, the 20 November, at 09:30',
    );
    expect(
      de.dateTimeString('Freitag', '20.11.', '09:30'),
      'Freitag, den 20.11. um 09:30 Uhr',
    );
    expect(
      [
        en.schoolCountString(0),
        en.schoolCountString(1),
        en.schoolCountString(2),
      ],
      ['No schools', '1 school', '2 schools'],
    );
    expect(
      [
        de.schoolCountString(0),
        de.schoolCountString(1),
        de.schoolCountString(2),
      ],
      ['Keine Schulen', '1 Schule', '2 Schulen'],
    );
    expect(
      en.conversationTypeDescription('noAnswerAllowed'),
      "Replies won't be possible.",
    );
    expect(en.conversationTypeName('unknown'), 'Error');
  });

  test(
    'missing German translations continue to fall back to English',
    () async {
      final de = await AppLocalizations.delegate.load(const Locale('de'));
      expect(de.welcomeBack, 'Welcome Back');
    },
  );
}
