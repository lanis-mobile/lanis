import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lanis/home_page.dart';

import '../core/database/account_database/account_db.dart';
import '../core/sph/sph.dart';
import '../models/client_status_exceptions.dart';
import 'logger.dart';

enum LoginStatus {
  waiting,
  done,
  error,
  setup;
}

/// Authenticates a user and set ups the global SPH instance.
class AuthenticationState {
  final ValueNotifier<LoginStatus> status = ValueNotifier(LoginStatus.waiting);
  final ValueNotifier<LanisException?> exception = ValueNotifier(null);

  Future<void> login() async {
    logger.i("Performing login...");
    sph?.prefs.close();
    status.value = LoginStatus.waiting;
    exception.value = null;
    sph = null;
    late final ClearTextAccount? account;
    account = await accountDatabase.getLastLoggedInAccount();
    logger.i("Last logged in account: $account");
    if (account != null) {
      sph = SPH(account: account);
    }
    if (sph == null) {
      status.value = LoginStatus.setup;
      return;
    }

    await sph?.session.prepareDio();
    logger.i("Prepared Dio for session");

    try {
      logger.i('Authenticating...');
      await sph?.session.authenticate();
      logger.i('Authenticated');

      homeKey.currentState?.resetState();

      if (exception.value == null) {
        status.value = LoginStatus.done;
      }
    } on (WrongCredentialsException, CredentialsIncompleteException) {
      status.value = LoginStatus.setup;
    } on LanisException catch (e) {
      exception.value = e;
      status.value = LoginStatus.error;
    }
  }

  /// Reauthenticate and reset application.
  void reset(final BuildContext context) {
    Phoenix.rebirth(context);
    login();
  }
}

final authenticationState = AuthenticationState();
