import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_keychain/flutter_keychain.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/account_types.dart';
import '../../../utils/logger.dart';
import '../../sph/sph.dart';
import 'kv_defaults.dart';

part 'account_db.g.dart';

/// Define Android options as recommended for encrypted shared preferences.
AndroidOptions _getAndroidOptions() => const AndroidOptions(
      encryptedSharedPreferences: true,
    );

/// Instantiate FlutterSecureStorage with android options.
/// iOS uses Keychain by default.
final FlutterSecureStorage secureStorage =
    FlutterSecureStorage(aOptions: _getAndroidOptions());

class ClearTextAccount {
  final int localId;
  final int schoolID;
  final String username;
  final String password;
  final String schoolName;
  final AccountType? accountType;
  final bool firstLogin;

  ClearTextAccount({
    required this.localId,
    required this.schoolID,
    required this.username,
    required this.password,
    required this.schoolName,
    this.accountType,
    this.firstLogin = false,
  });
}

class AppPreferencesTable extends Table {
  TextColumn get key => text().withLength(min: 1, max: 50)();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

class AccountsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get schoolId => integer()();
  TextColumn get schoolName => text()();
  TextColumn get username => text().withLength(min: 1, max: 50)();
  TextColumn get accountType => text().nullable()();
  TextColumn get passwordHash => text()();
  DateTimeColumn get lastLogin => dateTime().nullable()();
  DateTimeColumn get creationDate => dateTime()();
}

@DriftDatabase(tables: [AccountsTable, AppPreferencesTable])
class AccountDatabase extends _$AccountDatabase {
  late final KV kv = KV(this);

  AccountDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  /// Generates an encrypted password using a secure key stored
  /// via Flutter Secure Storage.
  static Future<String> cryptPassword(String password) async {
    String? key = await secureStorage.read(key: 'encryption_key');
    if (key == null) {
      final cryptKey = Key.fromSecureRandom(32); // 256 bits
      await secureStorage.write(key: 'encryption_key', value: cryptKey.base64);
      key = cryptKey.base64;
      logger.i('Generated new encryption key');
    }
    final cryptKey = Key.fromBase64(key);
    final iv = IV.fromSecureRandom(16); // 128 bits
    final encrypter = Encrypter(AES(cryptKey, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(password, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts the encrypted password using the key from secure storage.
  static Future<String> decryptPassword(String encryptedPassword) async {
    String? key = await secureStorage.read(key: 'encryption_key');

    /// TODO: Temporary migration from flutter_keychain to flutter_secure_storage. Remove in future.
    if (key == null) {
      key = await FlutterKeychain.get(key: 'encryption_key');

      if (key != null) {
        await secureStorage.write(key: 'encryption_key', value: key);
        await FlutterKeychain.remove(key: 'encryption_key');
        logger.i(
            'Migrated encryption key from flutter_keychain to flutter_secure_storage.');
      } else {
        throw Exception('Encryption key not found');
      }
    }

    final cryptKey = Key.fromBase64(key);
    final parts = encryptedPassword.split(':');
    if (parts.length != 2) {
      throw Exception('Invalid encrypted password format');
    }
    final iv = IV.fromBase64(parts[0]);
    final encrypter = Encrypter(AES(cryptKey, mode: AESMode.gcm));
    return encrypter.decrypt64(parts[1], iv: iv);
  }

  Future<void> updatePassword(int id, String newPasswordClearText) async {
    final passwordHash = await cryptPassword(newPasswordClearText);
    await (update(accountsTable)..where((tbl) => tbl.id.equals(id))).write(
      AccountsTableCompanion(
        passwordHash: Value(passwordHash),
      ),
    );
  }

  Future<void> setAccountType(int id, AccountType accountType) async {
    await (update(accountsTable)..where((tbl) => tbl.id.equals(id))).write(
      AccountsTableCompanion(
        accountType: Value(accountType.toString()),
      ),
    );
  }

  Future<int> addAccountToDatabase({
    required int schoolID,
    required String username,
    required String password,
    required String schoolName,
  }) async {
    String passwordHash = await cryptPassword(password);
    await into(accountsTable).insert(
      AccountsTableCompanion(
        schoolId: Value(schoolID),
        schoolName: Value(schoolName),
        username: Value(username),
        passwordHash: Value(passwordHash),
        lastLogin: Value(null),
        creationDate: Value(DateTime.now()),
      ),
    );
    final insertedAccount = await (select(accountsTable)
          ..where((tbl) =>
              tbl.schoolId.equals(schoolID) & tbl.username.equals(username)))
        .getSingle();
    return insertedAccount.id;
  }

  Future<ClearTextAccount?> getLastLoggedInAccount() async {
    final account0 = await (select(accountsTable)
          ..orderBy([
            (u) => OrderingTerm(
                expression: u.lastLogin,
                mode: OrderingMode.desc,
                nulls: NullsOrder.first),
          ]))
        .get();
    final account = account0.isNotEmpty ? account0.first : null;
    if (account == null) return null;

    return ClearTextAccount(
      localId: account.id,
      schoolID: account.schoolId,
      username: account.username,
      password: await decryptPassword(account.passwordHash),
      accountType: account.accountType != null
          ? accountTypeFromString(account.accountType!)
          : null,
      schoolName: account.schoolName,
      firstLogin: account.lastLogin == null,
    );
  }

  static Future<ClearTextAccount> getAccountFromTableData(
      AccountsTableData account) async {
    final String clearTextPassword =
        await decryptPassword(account.passwordHash);
    return ClearTextAccount(
      localId: account.id,
      schoolID: account.schoolId,
      username: account.username,
      password: clearTextPassword,
      schoolName: account.schoolName,
      accountType: account.accountType != null
          ? accountTypeFromString(account.accountType!)
          : null,
      firstLogin: account.lastLogin == null,
    );
  }

  Future<ClearTextAccount> getClearTextAccountFromId(int id) async {
    final account = await (select(accountsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingle();
    return getAccountFromTableData(account);
  }

  Future<void> deleteAccount(int id) async {
    if (id == sph?.account.localId) {
      sph?.prefs.close();
      final Directory databasesDirectory =
          await getApplicationDocumentsDirectory();
      final dbFile = File('${databasesDirectory.path}/session_${id}_db.sqlite');
      if (dbFile.existsSync()) {
        dbFile.deleteSync();
      }
    }
    final int rows =
        await (delete(accountsTable)..where((tbl) => tbl.id.equals(id))).go();
    if (rows == 0) {
      logger.w('Account with id $id not found');
    }
    final tempDir = await getTemporaryDirectory();
    final userDir = Directory("${tempDir.path}/$id");
    if (userDir.existsSync()) {
      userDir.deleteSync(recursive: true);
    }
  }

  void updateLastLogin(int id) async {
    await (update(accountsTable)..where((tbl) => tbl.id.equals(id))).write(
      AccountsTableCompanion(
        lastLogin: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setNextLogin(int id) async {
    if (sph == null) return;
    sph?.prefs.close();
    // check weather a account with null is already in the db and return if so
    final account = await (select(accountsTable)
          ..where((tbl) => tbl.lastLogin.isNull()))
        .get();
    if (account.isNotEmpty) {
      return;
    }

    await (update(accountsTable)..where((tbl) => tbl.id.equals(id))).write(
      AccountsTableCompanion(
        lastLogin: Value(null),
      ),
    );
  }

  Future<bool> doesAccountExist(int schoolID, String username) async {
    final account = await (select(accountsTable)
          ..where((tbl) =>
              tbl.schoolId.equals(schoolID) & tbl.username.equals(username)))
        .get();
    return account.isNotEmpty;
  }

  Future<void> deleteAllAccounts() async {
    await delete(accountsTable).go();
    final tempDir = await getTemporaryDirectory();
    final userDir = Directory(tempDir.path);
    if (userDir.existsSync()) {
      userDir.deleteSync(recursive: true);
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'accounts_database');
  }
}

class KV {
  final AccountDatabase db;

  KV(this.db);

  Future<void> set(String key, dynamic value) async {
    final insert = jsonEncode({'v': value});
    await db.into(db.appPreferencesTable).insert(
          AppPreferencesTableCompanion.insert(
            key: key,
            value: Value(insert),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<dynamic> get(String key) async {
    final val = (await (db.select(db.appPreferencesTable)
              ..where((tbl) => tbl.key.equals(key)))
            .getSingleOrNull())
        ?.value;
    if (val == null && kvDefaults.keys.contains(key)) {
      await set(key, kvDefaults[key]!);
      return kvDefaults[key];
    }
    return val != null ? jsonDecode(val)['v'] : null;
  }

  Future<Map<String, dynamic>> getMultiple(List<String> keys) {
    return (db.select(db.appPreferencesTable)
          ..where((tbl) => tbl.key.isIn(keys)))
        .get()
        .then((event) {
      final result = Map.fromEntries(event.map((e) =>
          MapEntry(e.key, e.value != null ? jsonDecode(e.value!)['v'] : null)));
      for (var key in keys) {
        if (!result.containsKey(key) && kvDefaults.containsKey(key)) {
          result[key] = kvDefaults[key];
        }
      }
      return result;
    });
  }

  Future<void> setMultiple(Map<String, dynamic> values) async {
    for (var entry in values.entries) {
      await set(entry.key, entry.value);
    }
  }

  Stream<dynamic> subscribe(String key) {
    final stream = (db.select(db.appPreferencesTable)
          ..where((tbl) => tbl.key.equals(key)))
        .watchSingleOrNull();
    return stream.map((event) {
      if (event?.value == null && kvDefaults.containsKey(key)) {
        return kvDefaults[key];
      }
      return event?.value != null ? jsonDecode(event!.value!)['v'] : null;
    });
  }

  Stream<Map<String, dynamic>> subscribeMultiple(List<String> keys) {
    final stream = (db.select(db.appPreferencesTable)
          ..where((tbl) => tbl.key.isIn(keys)))
        .watch();
    return stream.map((event) {
      final result = Map.fromEntries(event.map((e) =>
          MapEntry(e.key, e.value != null ? jsonDecode(e.value!)['v'] : null)));
      for (var key in keys) {
        if (!result.containsKey(key) && kvDefaults.containsKey(key)) {
          result[key] = kvDefaults[key];
        }
      }
      return result;
    });
  }
}

AccountType? accountTypeFromString(String src) {
  switch (src) {
    case 'AccountType.student':
      return AccountType.student;
    case 'AccountType.teacher':
      return AccountType.teacher;
    case 'AccountType.parent':
      return AccountType.parent;
    default:
      return null;
  }
}

late final AccountDatabase accountDatabase;
