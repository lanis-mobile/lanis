import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/auth_redirect.dart';
import 'package:lanis/utils/deep_link.dart';

void main() {
  const home = '/common/substitutions/home';

  String? resolve({
    required AuthPhase phase,
    required String loc,
    bool privacyAccepted = true,
    bool hasAccounts = true,
    bool isShellPath = false,
    bool shellSupported = true,
    String? deepLinkErrorPath,
  }) {
    return resolveAuthRedirect(
      phase: phase,
      loc: loc,
      privacyAccepted: privacyAccepted,
      hasAccounts: hasAccounts,
      isShellPath: isShellPath,
      shellSupported: shellSupported,
      deepLinkErrorPath: deepLinkErrorPath,
      homePath: () => home,
    );
  }

  group('privacy gate', () {
    test('forces privacy-policy only when accounts already exist', () {
      expect(
        resolve(
          phase: AuthPhase.authenticating,
          loc: '/startup',
          privacyAccepted: false,
          hasAccounts: true,
        ),
        '/privacy-policy',
      );
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/welcome',
          privacyAccepted: false,
          hasAccounts: true,
        ),
        '/privacy-policy',
      );
    });

    test('skips privacy-policy gate for empty first-time installs', () {
      expect(
        resolve(
          phase: AuthPhase.authenticating,
          loc: '/startup',
          privacyAccepted: false,
          hasAccounts: false,
        ),
        isNull,
      );
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/startup',
          privacyAccepted: false,
          hasAccounts: false,
        ),
        '/welcome',
      );
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/welcome',
          privacyAccepted: false,
          hasAccounts: false,
        ),
        isNull,
      );
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/privacy-policy',
          privacyAccepted: false,
          hasAccounts: false,
        ),
        '/welcome',
      );
    });

    test('allows staying on privacy-policy when accounts exist', () {
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/privacy-policy',
          privacyAccepted: false,
          hasAccounts: true,
        ),
        isNull,
      );
    });
  });

  group('authenticating', () {
    test('allows startup login accounts privacy', () {
      for (final loc in ['/startup', '/login', '/accounts', '/privacy-policy']) {
        expect(
          resolve(phase: AuthPhase.authenticating, loc: loc),
          isNull,
          reason: loc,
        );
      }
    });

    test('sends other locations to startup', () {
      expect(
        resolve(phase: AuthPhase.authenticating, loc: '/welcome'),
        '/startup',
      );
      expect(
        resolve(
          phase: AuthPhase.authenticating,
          loc: '/common/substitutions/home',
        ),
        '/startup',
      );
    });
  });

  group('unauthenticated', () {
    test('startup goes to welcome', () {
      expect(
        resolve(phase: AuthPhase.unauthenticated, loc: '/startup'),
        '/welcome',
      );
    });

    test('keeps welcome and login', () {
      expect(
        resolve(phase: AuthPhase.unauthenticated, loc: '/welcome'),
        isNull,
      );
      expect(
        resolve(phase: AuthPhase.unauthenticated, loc: '/login'),
        isNull,
      );
    });

    test('deep links go to welcome', () {
      expect(
        resolve(
          phase: AuthPhase.unauthenticated,
          loc: '/common/substitutions/home',
        ),
        '/welcome',
      );
    });
  });

  group('error', () {
    test('allows startup and login', () {
      expect(resolve(phase: AuthPhase.error, loc: '/startup'), isNull);
      expect(resolve(phase: AuthPhase.error, loc: '/login'), isNull);
    });

    test('other locations go to startup', () {
      expect(resolve(phase: AuthPhase.error, loc: '/welcome'), '/startup');
    });
  });

  group('authenticated', () {
    test('privacy and welcome/startup go home', () {
      expect(
        resolve(phase: AuthPhase.authenticated, loc: '/privacy-policy'),
        home,
      );
      expect(resolve(phase: AuthPhase.authenticated, loc: '/welcome'), home);
      expect(resolve(phase: AuthPhase.authenticated, loc: '/startup'), home);
    });

    test('login special-case stays', () {
      expect(resolve(phase: AuthPhase.authenticated, loc: '/login'), isNull);
    });

    test('deep link error path wins', () {
      expect(
        resolve(
          phase: AuthPhase.authenticated,
          loc: '/teacher/lessons/home',
          deepLinkErrorPath: SettingsDeepLinks.deepLinkError,
        ),
        SettingsDeepLinks.deepLinkError,
      );
    });

    test('unsupported shell path goes to deep-link error', () {
      expect(
        resolve(
          phase: AuthPhase.authenticated,
          loc: '/common/substitutions/home',
          isShellPath: true,
          shellSupported: false,
        ),
        SettingsDeepLinks.deepLinkError,
      );
    });

    test('supported shell stays', () {
      expect(
        resolve(
          phase: AuthPhase.authenticated,
          loc: '/common/substitutions/home',
          isShellPath: true,
          shellSupported: true,
        ),
        isNull,
      );
    });
  });
}
