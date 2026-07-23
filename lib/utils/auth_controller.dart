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
  @override
  AuthState build() => const AuthState.authenticating();

  /// Select preferred account (if any) and authenticate.
  Future<void> bootstrap() async {
    state = const AuthState.authenticating();
    try {
      final db = ref.read(lanisDatabaseProvider);
      final accounts = await db.listAccounts();
      if (accounts.isEmpty) {
        ref.read(activeAccountProvider.notifier).clear();
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

  Future<void> loginWithAccount(int accountId) async {
    state = const AuthState.authenticating();
    try {
      await ref.read(sessionProvider.notifier).deAuthenticate();
      await ref.read(activeAccountProvider.notifier).select(accountId);
      await ref.read(sessionProvider.notifier).authenticate();
      state = const AuthState.authenticated();
    } on LanisException catch (e) {
      if (e is WrongCredentialsException ||
          e is CredentialsIncompleteException) {
        state = const AuthState.unauthenticated();
      } else {
        state = AuthState.error(e);
      }
    }
  }

  Future<void> logout() async {
    await ref.read(sessionProvider.notifier).deAuthenticate();
    ref.read(activeAccountProvider.notifier).clear();
    state = const AuthState.unauthenticated();
  }

  Future<void> retry() => bootstrap();
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
