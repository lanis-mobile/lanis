import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/deep_link.dart';

void main() {
  group('deepLinkLocationFromUri', () {
    test('normalizes lanis host path', () {
      expect(
        deepLinkLocationFromUri(Uri.parse('lanis://common/substitutions/home')),
        '/common/substitutions/home',
      );
    });

    test('normalizes path-only lanis URI', () {
      expect(
        deepLinkLocationFromUri(Uri.parse('lanis:///student/lessons/home')),
        '/student/lessons/home',
      );
    });

    test('preserves query', () {
      expect(
        deepLinkLocationFromUri(
          Uri.parse('lanis://common/settings/home?tab=1'),
        ),
        '/common/settings/home?tab=1',
      );
    });

    test('rejects foreign schemes', () {
      expect(
        deepLinkLocationFromUri(Uri.parse('https://example.com/x')),
        isNull,
      );
    });

    test('rejects empty path', () {
      expect(deepLinkLocationFromUri(Uri.parse('lanis://')), isNull);
    });
  });

  group('deepLinkPrefixOf / Allowed', () {
    test('common prefix', () {
      expect(
        deepLinkPrefixOf('/common/substitutions/home'),
        DeepLinkPrefixes.common,
      );
      expect(
        deepLinkPrefixAllowed('/common/substitutions/home', AccountType.student),
        isTrue,
      );
    });

    test('account-typed prefix must match', () {
      expect(deepLinkPrefixOf('/teacher/lessons/home'), 'teacher');
      expect(
        deepLinkPrefixAllowed('/teacher/lessons/home', AccountType.teacher),
        isTrue,
      );
      expect(
        deepLinkPrefixAllowed('/teacher/lessons/home', AccountType.student),
        isFalse,
      );
    });

    test('unknown first segment', () {
      expect(deepLinkPrefixOf('/nope/x'), isNull);
      expect(deepLinkPrefixAllowed('/nope/x', AccountType.student), isFalse);
    });
  });

  test('SettingsDeepLinks constants', () {
    expect(SettingsDeepLinks.home, startsWith(SettingsDeepLinks.base));
    expect(SettingsDeepLinks.deepLinkError, '/deep-link-error');
  });
}
