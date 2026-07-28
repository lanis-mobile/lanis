import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/shell_navigation.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/theme_settings.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(resetAuthTestSeams);

  test('homeAppletPathsFor returns nested home paths', () {
    final paths = homeAppletPathsFor(AccountType.student);
    expect(paths, isNotEmpty);
    expect(paths.every((p) => p.endsWith('/home')), isTrue);
  });

  test('firstSupportedHomePathFor falls back when support set empty', () {
    final path = firstSupportedHomePathFor(
      supported: const {},
      accountType: AccountType.student,
    );
    expect(
      path,
      appletHomePath(AppDefinitions.homeApplets.first, AccountType.student),
    );
  });

  test('firstSupportedHomePathFor prefers supported applet', () {
    final calendar = AppDefinitions.homeApplets.firstWhere(
      (a) => a.appletPhpUrl == 'kalender.php',
    );
    final path = firstSupportedHomePathFor(
      supported: {'kalender.php'},
      accountType: AccountType.student,
    );
    expect(path, appletHomePath(calendar, AccountType.student));
  });

  test('themeSettingsProvider defaults', () {
    final container = ProviderContainer(overrides: LanisClient.configure());
    addTearDown(container.dispose);

    final map = container.read(themeSettingsProvider);
    expect(map['color'], 'standard');
    expect(map['theme'], 'system');
    expect(map['is-amoled'], isFalse);
  });

  test('themeSettingsProvider reflects shared settings after bump', () {
    final container = ProviderContainer(overrides: LanisClient.configure());
    addTearDown(container.dispose);

    final shared = container.read(sharedOverAccountSettingsProvider);
    shared.setString('color', 'teal');
    shared.setString('theme', 'dark');
    shared.setBool('is-amoled', true);
    container.read(themeRevisionProvider.notifier).bump();

    final map = container.read(themeSettingsProvider);
    expect(map['color'], 'teal');
    expect(map['theme'], 'dark');
    expect(map['is-amoled'], isTrue);
  });

  test('shouldRunBackgroundFetch follows privacy acceptance', () {
    final container = ProviderContainer(overrides: LanisClient.configure());
    addTearDown(container.dispose);
    final shared = container.read(sharedOverAccountSettingsProvider);

    expect(shouldRunBackgroundFetch(shared), isFalse);
    acceptPrivacy(container);
    expect(shouldRunBackgroundFetch(shared), isTrue);
  });
}
