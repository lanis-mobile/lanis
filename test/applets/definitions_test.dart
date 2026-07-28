import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/shell_navigation.dart';
import 'package:lanis/utils/deep_link.dart';

void main() {
  test('findMatchingLocation for substitutions home', () {
    final def = AppDefinitions.findMatchingLocation(
      '/common/substitutions/home',
    );
    expect(def, isNotNull);
    expect(def!.pathSegment, 'substitutions');
  });

  test('matchesLocation rejects unrelated path', () {
    final def = AppDefinitions.applets.firstWhere(
      (a) => a.pathSegment == 'substitutions',
    );
    expect(def.matchesLocation('/common/calendar/home'), isFalse);
  });

  test('shellBranchIndexForApplet is stable for home applets', () {
    final home = AppDefinitions.homeApplets;
    expect(home, isNotEmpty);
    for (var i = 0; i < home.length; i++) {
      expect(shellBranchIndexForApplet(home[i]), i);
    }
  });

  test('appletHomePath uses common prefix when scoped common', () {
    final def = AppDefinitions.applets.firstWhere(
      (a) => a.deepLinkScope == DeepLinkScope.common,
    );
    expect(appletHomePath(def, AccountType.student), def.homePath());
  });

  test('isAppletSupported respects account type', () {
    expect(
      AppDefinitions.isAppletSupported(AccountType.student, 'vertretungsplan.php'),
      isTrue,
    );
  });
}
