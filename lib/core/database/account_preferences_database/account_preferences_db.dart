import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'kv_defaults.dart';

part 'account_preferences_db.g.dart';

class AppPreferencesTable extends Table {
  TextColumn get key => text().withLength(min: 1, max: 50)();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

class AppletPreferencesTable extends Table {
  TextColumn get appletId => text().withLength(min: 1, max: 30)();
  TextColumn get key => text().withLength(min: 1, max: 50)();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {appletId, key};
}

class NotificationsDuplicatesTable extends Table {
  IntColumn get notificationId => integer()();
  TextColumn get appletId => text().withLength(min: 1, max: 30)();
  TextColumn get hash => text()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {notificationId, appletId};
}

class AppletData extends Table {
  TextColumn get appletId => text().withLength(min: 1, max: 30)();
  TextColumn get json => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {appletId};
}

@DriftDatabase(tables: [
  AppPreferencesTable,
  AppletPreferencesTable,
  AppletData,
  NotificationsDuplicatesTable
])
class AccountPreferencesDatabase extends _$AccountPreferencesDatabase {
  late final KV kv = KV(this);
  final int localId;

  AccountPreferencesDatabase({required this.localId})
      : super(_openConnection(localId));

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection(int id) {
    return driftDatabase(name: 'session_${id}_db');
  }

  Future<NotificationsDuplicatesTableData?> getNotificationDuplicates(
      int id, String appletId) async {
    return (await (select(notificationsDuplicatesTable)
          ..where((tbl) =>
              tbl.notificationId.equals(id) & tbl.appletId.equals(appletId)))
        .getSingleOrNull());
  }

  Future<void> updateNotificationDuplicate(
      int id, String appletId, String hash) async {
    await into(notificationsDuplicatesTable).insert(
        NotificationsDuplicatesTableCompanion.insert(
            notificationId: id,
            appletId: appletId,
            hash: hash,
            timestamp: DateTime.now()),
        mode: InsertMode.insertOrReplace);
  }

  Future<void> setAppletData(String appletId, String json) async {
    await into(appletData).insert(
        AppletDataCompanion.insert(
            appletId: appletId, json: Value(json), timestamp: DateTime.now()),
        mode: InsertMode.insertOrReplace);
  }

  Future<AppletDataData?> getAppletData(String appletId) async {
    return (await (select(appletData)
          ..where((tbl) => tbl.appletId.equals(appletId)))
        .getSingleOrNull());
  }

  Future<List<AppletDataData>> getAllAppletData(String appletId) async {
    return select(appletData).get();
  }
}

class KV {
  final AccountPreferencesDatabase db;

  KV(this.db);

  Future<void> set(String key, dynamic value) async {
    final insert = jsonEncode({'v': value});
    await db.into(db.appPreferencesTable).insert(
        AppPreferencesTableCompanion.insert(key: key, value: Value(insert)),
        mode: InsertMode.insertOrReplace);
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
        if (!result.containsKey(key)) {
          result[key] = kvDefaults.containsKey(key) ? kvDefaults[key] : null;
        }
      }
      return result;
    });
  }

  Stream<Map<String, dynamic>> subscribeAllApplet(
      String appletId, Map<String, dynamic> defaults) {
    final stream = (db.select(db.appletPreferencesTable)
          ..where((tbl) => tbl.appletId.equals(appletId)))
        .watch();
    return stream.map((event) {
      final result = Map.fromEntries(event.map((e) =>
          MapEntry(e.key, e.value != null ? jsonDecode(e.value!)['v'] : null)));
      for (var key in defaults.keys) {
        if (!result.containsKey(key) && defaults.containsKey(key)) {
          result[key] = defaults[key];
        }
      }
      return result;
    });
  }

  Future<Map<String, dynamic>> getAllApplet(
      String appletId, Map<String, dynamic> defaults) async {
    final result = Map<String, dynamic>.fromEntries(
        (await (db.select(db.appletPreferencesTable)
                  ..where((tbl) => tbl.appletId.equals(appletId)))
                .get())
            .map((e) => MapEntry(
                e.key, e.value != null ? jsonDecode(e.value!)['v'] : null)));
    for (var key in defaults.keys) {
      if (!result.containsKey(key) && defaults.containsKey(key)) {
        result[key] = defaults[key];
      }
    }
    return result;
  }

  Future<void> setAppletValue(
      String appletId, String key, dynamic value) async {
    final insert = jsonEncode({'v': value});
    await db.into(db.appletPreferencesTable).insert(
        AppletPreferencesTableCompanion.insert(
            appletId: appletId, key: key, value: Value(insert)),
        mode: InsertMode.insertOrReplace);
  }

  Future<dynamic> getAppletValue(String appletId, String key) async {
    final val = (await (db.select(db.appletPreferencesTable)
              ..where(
                  (tbl) => tbl.appletId.equals(appletId) & tbl.key.equals(key)))
            .getSingleOrNull())
        ?.value;
    return val != null ? jsonDecode(val)['v'] : null;
  }
}
