import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Keep implicit DateFormat/NumberFormat calls aligned with the app language.
/// The old localization delegate did this when loading each locale.
Locale resolveAppLocale(
  List<Locale>? locales,
  Iterable<Locale> supportedLocales,
) {
  final resolved = basicLocaleListResolution(locales, supportedLocales);
  Intl.defaultLocale = Intl.canonicalizedLocale(resolved.toLanguageTag());
  return resolved;
}
