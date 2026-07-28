import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/privacy_policy.dart';

/// Controllable stand-in for [sessionProvider.notifier.authenticate].
enum FakeAuthResult { success, wrongCredentials, noConnection, lanisDown }

/// Installs [AuthController.debugAuthenticate] / [debugDeauthenticate].
///
/// Call [AuthController.resetDebugAuth] in tearDown.
void installFakeSessionAuth({
  FakeAuthResult Function()? nextResult,
  FakeAuthResult result = FakeAuthResult.success,
}) {
  AuthController.debugAuthenticate = (ref) async {
    final r = nextResult?.call() ?? result;
    switch (r) {
      case FakeAuthResult.success:
        return;
      case FakeAuthResult.wrongCredentials:
        throw WrongCredentialsException();
      case FakeAuthResult.noConnection:
        throw NoConnectionException();
      case FakeAuthResult.lanisDown:
        throw LanisDownException();
    }
  };
  AuthController.debugDeauthenticate = (_) async {};
}

ProviderContainer createAuthTestContainer() {
  final container = ProviderContainer(overrides: LanisClient.configure());
  return container;
}

Future<int> addTestAccount(
  ProviderContainer container, {
  int schoolId = 1,
  String schoolName = 'Test School',
  String username = 'user',
  String password = 'secret',
  AccountType? accountType = AccountType.student,
}) {
  return container.read(accountsProvider.notifier).add(
    schoolId: schoolId,
    schoolName: schoolName,
    username: username,
    password: password,
    accountType: accountType,
  );
}

void acceptPrivacy(ProviderContainer container) {
  acceptPrivacyPolicy(container.read(sharedOverAccountSettingsProvider));
}
