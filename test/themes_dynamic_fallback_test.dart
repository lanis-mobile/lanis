import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/themes.dart';

void main() {
  test('dynamic theme null lightTheme can fall back to standard', () {
    // Reset to the production default uninitialized dynamic theme.
    Themes.dynamicTheme = Themes(null, null);

    Themes theme = Themes.standardTheme;
    final dynamicTheme = Themes.dynamicTheme;
    if (dynamicTheme.lightTheme != null) {
      theme = Themes(dynamicTheme.lightTheme, dynamicTheme.darkTheme);
    }

    final lightTheme = theme.lightTheme ?? Themes.standardTheme.lightTheme!;
    final darkTheme = theme.darkTheme ?? Themes.standardTheme.darkTheme!;

    expect(lightTheme, isNotNull);
    expect(darkTheme, isNotNull);
    expect(theme.lightTheme, Themes.standardTheme.lightTheme);
  });
}
