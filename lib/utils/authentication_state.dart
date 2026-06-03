import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lanis/core/connection_checker.dart';
import 'package:lanis/core/demo/demo_parsers.dart';
import 'package:lanis/core/widget_data_service.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/models/account_types.dart';

import '../core/database/account_database/account_db.dart';
import '../core/sph/sph.dart';
import '../models/client_status_exceptions.dart';
import 'phoenix.dart';
import 'logger.dart';

enum LoginStatus { waiting, done, error, setup }

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
        if (sph != null) {
          WidgetDataService.instance
              .updateAll(sph!, sph!.session.accountType)
              .ignore();
        }
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

  Future<void> loginDemo(AccountType accountType) async {
    if (!kDebugMode) throw StateError('loginDemo must only be called in debug mode');
    status.value = LoginStatus.waiting;
    exception.value = null;
    sph?.prefs.close();
    sph = null;

    sph = SPH(
      account: ClearTextAccount(
        localId: -1,
        schoolID: 0,
        username: 'demo',
        password: '',
        schoolName: 'Demo-Schule',
        accountType: accountType,
      ),
    );

    sph!.session.userData = {'vorname': 'Max', 'nachname': 'Mustermann'};
    sph!.session.setDemoAccountType(accountType);
    sph!.parser = DemoParsers(sph: sph!);
    connectionChecker.status = ConnectionStatus.connected;

    status.value = LoginStatus.done;
  }
}

final authenticationState = AuthenticationState();
