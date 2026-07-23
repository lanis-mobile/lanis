import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

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

  @override
  AuthState build() => const AuthState.authenticating();

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
      if (accounts.isEmpty) {
        await ref.read(activeAccountProvider.notifier).clear();
        state = const AuthState.unauthenticated();
        return;
      }

      await ref.read(activeAccountProvider.notifier).selectPreferred();
      if (ref.read(activeAccountProvider) == null) {
        state = const AuthState.unauthenticated();
        return;
      }

      await ref.read(sessionProvider.notifier).authenticate();
      state = const AuthState.authenticated();
    } on WrongCredentialsException {
      state = const AuthState.unauthenticated();
    } on CredentialsIncompleteException {
      state = const AuthState.unauthenticated();
    } on LanisException catch (e) {
      state = AuthState.error(e);
    } catch (e) {
      state = AuthState.error(UnknownException(e.toString()));
    }
  }

  /// Returns whether authentication succeeded.
  Future<bool> loginWithAccount(int accountId) async {
    _authDrivenExternally = true;
    final previousId = ref.read(activeAccountProvider)?.localId;
    state = const AuthState.authenticating();
    try {
      // [ActiveAccount.select] deauthenticates the previous session and
      // invalidates account-scoped providers (parsers, settings, feature set).
      await ref.read(activeAccountProvider.notifier).select(accountId);
      await ref.read(sessionProvider.notifier).authenticate();
      state = const AuthState.authenticated();
      return true;
    } catch (e) {
      // Restore the previous account so a failed switch doesn't leave the user
      // logged out of a working session.
      if (previousId != null && previousId != accountId) {
        try {
          await ref.read(activeAccountProvider.notifier).select(previousId);
          await ref.read(sessionProvider.notifier).authenticate();
          state = const AuthState.authenticated();
        } catch (_) {
          // Fall through to surface the original failure below.
        }
      }

      if (e is WrongCredentialsException ||
          e is CredentialsIncompleteException) {
        if (state.phase != AuthPhase.authenticated) {
          state = const AuthState.unauthenticated();
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
    await ref.read(sessionProvider.notifier).deAuthenticate();
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
