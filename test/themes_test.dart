import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/themes.dart';

void main() {
  test('flutterColorThemes contains expected keys', () {
    expect(Themes.flutterColorThemes.keys, containsAll(['pink', 'blue', 'teal']));
    expect(Themes.flutterColorThemes['blue']?.lightTheme, isNotNull);
    expect(Themes.flutterColorThemes['blue']?.darkTheme, isNotNull);
  });

  test('getNewTheme builds light and dark schemes', () {
    final theme = Themes.getNewTheme(Colors.teal);
    expect(theme.lightTheme!.brightness, Brightness.light);
    expect(theme.darkTheme!.brightness, Brightness.dark);
  });

  test('getAmoledThemes forces black dark scaffold', () {
    final base = Themes.getNewTheme(Colors.indigo);
    final amoled = Themes.getAmoledThemes(base);
    expect(amoled.darkTheme!.scaffoldBackgroundColor, Colors.black);
    expect(amoled.lightTheme, same(base.lightTheme));
  });
}
