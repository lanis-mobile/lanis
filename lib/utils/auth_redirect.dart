import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/deep_link.dart';

/// Pure auth/privacy redirect used by [goRouterProvider].
///
/// Returns a location to redirect to, or `null` to stay on [loc].
///
/// The blocking privacy-policy update screen is only for installs that already
/// have an account. First-time users accept the policy on the login form.
String? resolveAuthRedirect({
  required AuthPhase phase,
  required String loc,
  required bool privacyAccepted,
  required bool hasAccounts,
  required bool isShellPath,
  required bool shellSupported,
  required String? deepLinkErrorPath,
  required String Function() homePath,
}) {
  final loggingIn = loc == '/welcome' || loc == '/login';
  final onStartup = loc == '/startup';
  final onPrivacyPolicy = loc == '/privacy-policy';

  if (!privacyAccepted && !onPrivacyPolicy && hasAccounts) {
    return '/privacy-policy';
  }

  switch (phase) {
    case AuthPhase.authenticating:
      if (onStartup ||
          onPrivacyPolicy ||
          loc == '/login' ||
          loc == '/accounts') {
        return null;
      }
      return '/startup';
    case AuthPhase.unauthenticated:
      if (onPrivacyPolicy) {
        // Empty installs should not stay on the update gate.
        return hasAccounts ? null : '/welcome';
      }
      if (loggingIn || onStartup) {
        if (onStartup) return '/welcome';
        return null;
      }
      return '/welcome';
    case AuthPhase.error:
      if (onPrivacyPolicy || loc == '/login') return null;
      return onStartup ? null : '/startup';
    case AuthPhase.authenticated:
      if (onPrivacyPolicy) {
        return homePath();
      }
      if (loggingIn && loc == '/login') return null;
      if (loc == '/welcome' || onStartup) {
        return homePath();
      }
      if (deepLinkErrorPath != null) return deepLinkErrorPath;
      if (isShellPath && !shellSupported) {
        return SettingsDeepLinks.deepLinkError;
      }
      return null;
  }
}
