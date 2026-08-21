import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/bridge/login_telemetry.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/spam_alessio.dart';

enum AuthPhase { unauthenticated, authenticating, authenticated, error }

class AuthState {
  final AuthPhase phase;
  final LanisException? exception;

  const AuthState({required this.phase, this.exception});

  const AuthState.unauthenticated()
    : phase = AuthPhase.unauthenticated,
      exception = null;

  const AuthState.authenticating()
    : phase = AuthPhase.authenticating,
      exception = null;

  const AuthState.authenticated()
    : phase = AuthPhase.authenticated,
      exception = null;

  AuthState.error(this.exception) : phase = AuthPhase.error;
}

class AuthController extends Notifier<AuthState> {
  /// Prevents [StartupScreen] from calling [bootstrap] while a login/switch
  /// is already in flight (redirect to `/startup` would otherwise race).
  bool _authDrivenExternally = false;

  /// Test-only: when set, replaces [sessionProvider.notifier.authenticate].
  @visibleForTesting
  static Future<void> Function(Ref ref)? debugAuthenticate;

  /// Test-only: when set, replaces [sessionProvider.notifier.deAuthenticate].
  @visibleForTesting
  static Future<void> Function(Ref ref)? debugDeauthenticate;

  /// Whether the last [bootstrap]/[loginWithAccount] used the network/fake auth.
  @visibleForTesting
  static int authenticateCallCount = 0;

  @visibleForTesting
  static void resetDebugAuth() {
    debugAuthenticate = null;
    debugDeauthenticate = null;
    authenticateCallCount = 0;
  }

  @override
  AuthState build() => const AuthState.authenticating();

  Future<void> _authenticate() async {
    authenticateCallCount++;
    final override = debugAuthenticate;
    if (override != null) {
      await override(ref);
      return;
    }
    await authenticateWithLoginTelemetry(ref.read(sessionProvider.notifier));
  }

  Future<void> _deauthenticate() async {
    final override = debugDeauthenticate;
    if (override != null) {
      await override(ref);
      return;
    }
    await ref.read(sessionProvider.notifier).deAuthenticate();
  }

  /// Cold-start entry from [StartupScreen] only.
  Future<void> bootstrapIfNeeded() async {
    if (state.phase == AuthPhase.authenticated) return;
    if (state.phase == AuthPhase.error) return;
    if (_authDrivenExternally) return;
    await bootstrap();
  }

  /// Select preferred account (if any) and authenticate.
  Future<void> bootstrap() async {
    _authDrivenExternally = true;
    state = const AuthState.authenticating();
    try {
      final db = ref.read(lanisDatabaseProvider);
      final accounts = await db.listAccounts();

      spamAlessio("try login");

      if (accounts.isEmpty) {
        spamAlessio("accounts.isEmpty");
        await ref.read(activeAccountProvider.notifier).clear();
        state = const AuthState.unauthenticated();
        return;
      }

      final shared = ref.read(sharedOverAccountSettingsProvider);
      if (!isPrivacyPolicyAccepted(shared)) {
        // Returning users must accept the update gate before auth continues.
        spamAlessio("!isPrivacyPolicyAccepted");
        state = const AuthState.unauthenticated();
        return;
      }

      await ref.read(activeAccountProvider.notifier).selectPreferred();
      if (ref.read(activeAccountProvider) == null) {
        spamAlessio("ref.read(activeAccountProvider) == null");
        state = const AuthState.unauthenticated();
        return;
      }

      await _authenticate();
      state = const AuthState.authenticated();
      spamAlessio("authenticated");
    } on WrongCredentialsException catch (e) {
      // Keep the failed account selected so ResetAccountPage can fix credentials.
      state = AuthState.error(e);
    } on CredentialsIncompleteException catch (e) {
      state = AuthState.error(e);
    } on LanisException catch (e) {
      state = AuthState.error(e);
    } catch (e) {
      state = AuthState.error(UnknownException(e.toString()));
    }
  }

  /// Returns whether authentication succeeded.
  ///
  /// When [removeAccountOnFailure] is true (new account add), the account is
  /// deleted if login fails — even if the login UI was unmounted by redirect.
  Future<bool> loginWithAccount(
    int accountId, {
    bool removeAccountOnFailure = false,
  }) async {
    final shared = ref.read(sharedOverAccountSettingsProvider);
    if (!isPrivacyPolicyAccepted(shared)) {
      state = const AuthState.unauthenticated();
      return false;
    }

    _authDrivenExternally = true;
    final previousId = ref.read(activeAccountProvider)?.localId;
    state = const AuthState.authenticating();
    try {
      // [ActiveAccount.select] deauthenticates the previous session and
      // invalidates account-scoped providers (parsers, settings, feature set).
      await ref.read(activeAccountProvider.notifier).select(accountId);
      await _authenticate();
      state = const AuthState.authenticated();
      return true;
    } catch (e) {
      if (removeAccountOnFailure) {
        try {
          await ref.read(accountsProvider.notifier).remove(accountId);
        } catch (_) {}
      }
      // Restore the previous account so a failed switch doesn't leave the user
      // logged out of a working session.
      if (previousId != null && previousId != accountId) {
        try {
          await ref.read(activeAccountProvider.notifier).select(previousId);
          await _authenticate();
          state = const AuthState.authenticated();
        } catch (_) {
          // Fall through to surface the original failure below.
        }
      }

      if (e is WrongCredentialsException ||
          e is CredentialsIncompleteException) {
        if (state.phase != AuthPhase.authenticated) {
          // Keep the selected account so ResetAccount / retry stay usable.
          state = AuthState.error(e as LanisException);
        }
        return false;
      }
      if (e is LanisException) {
        if (state.phase != AuthPhase.authenticated) {
          state = AuthState.error(e);
        }
        return false;
      }
      if (state.phase != AuthPhase.authenticated) {
        state = AuthState.error(UnknownException(e.toString()));
      }
      return false;
    }
  }

  Future<void> logout() async {
    await _deauthenticate();
    await ref
        .read(activeAccountProvider.notifier)
        .clear(skipDeauthenticate: true);
    state = const AuthState.unauthenticated();
  }

  /// Remove an account; bootstrap another if any remain, else log out.
  Future<void> removeAccountAndContinue(int accountId) async {
    final wasActive = ref.read(activeAccountProvider)?.localId == accountId;
    if (wasActive) {
      _authDrivenExternally = true;
      state = const AuthState.authenticating();
    }
    await ref.read(accountsProvider.notifier).remove(accountId);
    if (!wasActive) return;

    final remaining = await ref.read(accountsProvider.future);
    if (remaining.isEmpty) {
      state = const AuthState.unauthenticated();
      return;
    }
    await bootstrap();
  }

  Future<void> retry() => bootstrap();
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
