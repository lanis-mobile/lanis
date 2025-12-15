import 'package:lanis/core/sph/parsers.dart';
import 'package:lanis/core/sph/session.dart';
import 'package:lanis/core/sph/storage.dart';

import '../database/account_database/account_db.dart';
import '../database/account_preferences_database/account_preferences_db.dart';

class SPH {
  final ClearTextAccount account;
  late Parsers parser = Parsers(sph: this);
  late SessionHandler session =
      SessionHandler(sph: this, withLoginURL: withLoginURL);
  late StorageManager storage = StorageManager(sph: this);
  late AccountPreferencesDatabase prefs =
      AccountPreferencesDatabase(localId: account.localId);
  String? withLoginURL;

  SPH({required this.account, this.withLoginURL});
}

SPH? sph;
