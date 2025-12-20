// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_preferences_db.dart';

// ignore_for_file: type=lint
class $AppPreferencesTableTable extends AppPreferencesTable
    with TableInfo<$AppPreferencesTableTable, AppPreferencesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPreferencesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_preferences_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppPreferencesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppPreferencesTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPreferencesTableData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $AppPreferencesTableTable createAlias(String alias) {
    return $AppPreferencesTableTable(attachedDatabase, alias);
  }
}

class AppPreferencesTableData extends DataClass
    implements Insertable<AppPreferencesTableData> {
  final String key;
  final String? value;
  const AppPreferencesTableData({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  AppPreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return AppPreferencesTableCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory AppPreferencesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPreferencesTableData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  AppPreferencesTableData copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => AppPreferencesTableData(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  AppPreferencesTableData copyWithCompanion(AppPreferencesTableCompanion data) {
    return AppPreferencesTableData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesTableData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPreferencesTableData &&
          other.key == this.key &&
          other.value == this.value);
}

class AppPreferencesTableCompanion
    extends UpdateCompanion<AppPreferencesTableData> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const AppPreferencesTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppPreferencesTableCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<AppPreferencesTableData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppPreferencesTableCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return AppPreferencesTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppletPreferencesTableTable extends AppletPreferencesTable
    with TableInfo<$AppletPreferencesTableTable, AppletPreferencesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppletPreferencesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _appletIdMeta = const VerificationMeta(
    'appletId',
  );
  @override
  late final GeneratedColumn<String> appletId = GeneratedColumn<String>(
    'applet_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [appletId, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'applet_preferences_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppletPreferencesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('applet_id')) {
      context.handle(
        _appletIdMeta,
        appletId.isAcceptableOrUnknown(data['applet_id']!, _appletIdMeta),
      );
    } else if (isInserting) {
      context.missing(_appletIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {appletId, key};
  @override
  AppletPreferencesTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppletPreferencesTableData(
      appletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}applet_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $AppletPreferencesTableTable createAlias(String alias) {
    return $AppletPreferencesTableTable(attachedDatabase, alias);
  }
}

class AppletPreferencesTableData extends DataClass
    implements Insertable<AppletPreferencesTableData> {
  final String appletId;
  final String key;
  final String? value;
  const AppletPreferencesTableData({
    required this.appletId,
    required this.key,
    this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['applet_id'] = Variable<String>(appletId);
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  AppletPreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return AppletPreferencesTableCompanion(
      appletId: Value(appletId),
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory AppletPreferencesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppletPreferencesTableData(
      appletId: serializer.fromJson<String>(json['appletId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'appletId': serializer.toJson<String>(appletId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  AppletPreferencesTableData copyWith({
    String? appletId,
    String? key,
    Value<String?> value = const Value.absent(),
  }) => AppletPreferencesTableData(
    appletId: appletId ?? this.appletId,
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  AppletPreferencesTableData copyWithCompanion(
    AppletPreferencesTableCompanion data,
  ) {
    return AppletPreferencesTableData(
      appletId: data.appletId.present ? data.appletId.value : this.appletId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppletPreferencesTableData(')
          ..write('appletId: $appletId, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(appletId, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppletPreferencesTableData &&
          other.appletId == this.appletId &&
          other.key == this.key &&
          other.value == this.value);
}

class AppletPreferencesTableCompanion
    extends UpdateCompanion<AppletPreferencesTableData> {
  final Value<String> appletId;
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const AppletPreferencesTableCompanion({
    this.appletId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppletPreferencesTableCompanion.insert({
    required String appletId,
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : appletId = Value(appletId),
       key = Value(key);
  static Insertable<AppletPreferencesTableData> custom({
    Expression<String>? appletId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (appletId != null) 'applet_id': appletId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppletPreferencesTableCompanion copyWith({
    Value<String>? appletId,
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return AppletPreferencesTableCompanion(
      appletId: appletId ?? this.appletId,
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (appletId.present) {
      map['applet_id'] = Variable<String>(appletId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppletPreferencesTableCompanion(')
          ..write('appletId: $appletId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppletDataTable extends AppletData
    with TableInfo<$AppletDataTable, AppletDataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppletDataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _appletIdMeta = const VerificationMeta(
    'appletId',
  );
  @override
  late final GeneratedColumn<String> appletId = GeneratedColumn<String>(
    'applet_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [appletId, json, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'applet_data';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppletDataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('applet_id')) {
      context.handle(
        _appletIdMeta,
        appletId.isAcceptableOrUnknown(data['applet_id']!, _appletIdMeta),
      );
    } else if (isInserting) {
      context.missing(_appletIdMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {appletId};
  @override
  AppletDataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppletDataData(
      appletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}applet_id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $AppletDataTable createAlias(String alias) {
    return $AppletDataTable(attachedDatabase, alias);
  }
}

class AppletDataData extends DataClass implements Insertable<AppletDataData> {
  final String appletId;
  final String? json;
  final DateTime timestamp;
  const AppletDataData({
    required this.appletId,
    this.json,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['applet_id'] = Variable<String>(appletId);
    if (!nullToAbsent || json != null) {
      map['json'] = Variable<String>(json);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  AppletDataCompanion toCompanion(bool nullToAbsent) {
    return AppletDataCompanion(
      appletId: Value(appletId),
      json: json == null && nullToAbsent ? const Value.absent() : Value(json),
      timestamp: Value(timestamp),
    );
  }

  factory AppletDataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppletDataData(
      appletId: serializer.fromJson<String>(json['appletId']),
      json: serializer.fromJson<String?>(json['json']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'appletId': serializer.toJson<String>(appletId),
      'json': serializer.toJson<String?>(json),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  AppletDataData copyWith({
    String? appletId,
    Value<String?> json = const Value.absent(),
    DateTime? timestamp,
  }) => AppletDataData(
    appletId: appletId ?? this.appletId,
    json: json.present ? json.value : this.json,
    timestamp: timestamp ?? this.timestamp,
  );
  AppletDataData copyWithCompanion(AppletDataCompanion data) {
    return AppletDataData(
      appletId: data.appletId.present ? data.appletId.value : this.appletId,
      json: data.json.present ? data.json.value : this.json,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppletDataData(')
          ..write('appletId: $appletId, ')
          ..write('json: $json, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(appletId, json, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppletDataData &&
          other.appletId == this.appletId &&
          other.json == this.json &&
          other.timestamp == this.timestamp);
}

class AppletDataCompanion extends UpdateCompanion<AppletDataData> {
  final Value<String> appletId;
  final Value<String?> json;
  final Value<DateTime> timestamp;
  final Value<int> rowid;
  const AppletDataCompanion({
    this.appletId = const Value.absent(),
    this.json = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppletDataCompanion.insert({
    required String appletId,
    this.json = const Value.absent(),
    required DateTime timestamp,
    this.rowid = const Value.absent(),
  }) : appletId = Value(appletId),
       timestamp = Value(timestamp);
  static Insertable<AppletDataData> custom({
    Expression<String>? appletId,
    Expression<String>? json,
    Expression<DateTime>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (appletId != null) 'applet_id': appletId,
      if (json != null) 'json': json,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppletDataCompanion copyWith({
    Value<String>? appletId,
    Value<String?>? json,
    Value<DateTime>? timestamp,
    Value<int>? rowid,
  }) {
    return AppletDataCompanion(
      appletId: appletId ?? this.appletId,
      json: json ?? this.json,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (appletId.present) {
      map['applet_id'] = Variable<String>(appletId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppletDataCompanion(')
          ..write('appletId: $appletId, ')
          ..write('json: $json, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationsDuplicatesTableTable extends NotificationsDuplicatesTable
    with
        TableInfo<
          $NotificationsDuplicatesTableTable,
          NotificationsDuplicatesTableData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationsDuplicatesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appletIdMeta = const VerificationMeta(
    'appletId',
  );
  @override
  late final GeneratedColumn<String> appletId = GeneratedColumn<String>(
    'applet_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    notificationId,
    appletId,
    hash,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications_duplicates_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationsDuplicatesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notificationIdMeta);
    }
    if (data.containsKey('applet_id')) {
      context.handle(
        _appletIdMeta,
        appletId.isAcceptableOrUnknown(data['applet_id']!, _appletIdMeta),
      );
    } else if (isInserting) {
      context.missing(_appletIdMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {notificationId, appletId};
  @override
  NotificationsDuplicatesTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationsDuplicatesTableData(
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      )!,
      appletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}applet_id'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $NotificationsDuplicatesTableTable createAlias(String alias) {
    return $NotificationsDuplicatesTableTable(attachedDatabase, alias);
  }
}

class NotificationsDuplicatesTableData extends DataClass
    implements Insertable<NotificationsDuplicatesTableData> {
  final int notificationId;
  final String appletId;
  final String hash;
  final DateTime timestamp;
  const NotificationsDuplicatesTableData({
    required this.notificationId,
    required this.appletId,
    required this.hash,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['notification_id'] = Variable<int>(notificationId);
    map['applet_id'] = Variable<String>(appletId);
    map['hash'] = Variable<String>(hash);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  NotificationsDuplicatesTableCompanion toCompanion(bool nullToAbsent) {
    return NotificationsDuplicatesTableCompanion(
      notificationId: Value(notificationId),
      appletId: Value(appletId),
      hash: Value(hash),
      timestamp: Value(timestamp),
    );
  }

  factory NotificationsDuplicatesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationsDuplicatesTableData(
      notificationId: serializer.fromJson<int>(json['notificationId']),
      appletId: serializer.fromJson<String>(json['appletId']),
      hash: serializer.fromJson<String>(json['hash']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'notificationId': serializer.toJson<int>(notificationId),
      'appletId': serializer.toJson<String>(appletId),
      'hash': serializer.toJson<String>(hash),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  NotificationsDuplicatesTableData copyWith({
    int? notificationId,
    String? appletId,
    String? hash,
    DateTime? timestamp,
  }) => NotificationsDuplicatesTableData(
    notificationId: notificationId ?? this.notificationId,
    appletId: appletId ?? this.appletId,
    hash: hash ?? this.hash,
    timestamp: timestamp ?? this.timestamp,
  );
  NotificationsDuplicatesTableData copyWithCompanion(
    NotificationsDuplicatesTableCompanion data,
  ) {
    return NotificationsDuplicatesTableData(
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
      appletId: data.appletId.present ? data.appletId.value : this.appletId,
      hash: data.hash.present ? data.hash.value : this.hash,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsDuplicatesTableData(')
          ..write('notificationId: $notificationId, ')
          ..write('appletId: $appletId, ')
          ..write('hash: $hash, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(notificationId, appletId, hash, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationsDuplicatesTableData &&
          other.notificationId == this.notificationId &&
          other.appletId == this.appletId &&
          other.hash == this.hash &&
          other.timestamp == this.timestamp);
}

class NotificationsDuplicatesTableCompanion
    extends UpdateCompanion<NotificationsDuplicatesTableData> {
  final Value<int> notificationId;
  final Value<String> appletId;
  final Value<String> hash;
  final Value<DateTime> timestamp;
  final Value<int> rowid;
  const NotificationsDuplicatesTableCompanion({
    this.notificationId = const Value.absent(),
    this.appletId = const Value.absent(),
    this.hash = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationsDuplicatesTableCompanion.insert({
    required int notificationId,
    required String appletId,
    required String hash,
    required DateTime timestamp,
    this.rowid = const Value.absent(),
  }) : notificationId = Value(notificationId),
       appletId = Value(appletId),
       hash = Value(hash),
       timestamp = Value(timestamp);
  static Insertable<NotificationsDuplicatesTableData> custom({
    Expression<int>? notificationId,
    Expression<String>? appletId,
    Expression<String>? hash,
    Expression<DateTime>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (notificationId != null) 'notification_id': notificationId,
      if (appletId != null) 'applet_id': appletId,
      if (hash != null) 'hash': hash,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationsDuplicatesTableCompanion copyWith({
    Value<int>? notificationId,
    Value<String>? appletId,
    Value<String>? hash,
    Value<DateTime>? timestamp,
    Value<int>? rowid,
  }) {
    return NotificationsDuplicatesTableCompanion(
      notificationId: notificationId ?? this.notificationId,
      appletId: appletId ?? this.appletId,
      hash: hash ?? this.hash,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (appletId.present) {
      map['applet_id'] = Variable<String>(appletId.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsDuplicatesTableCompanion(')
          ..write('notificationId: $notificationId, ')
          ..write('appletId: $appletId, ')
          ..write('hash: $hash, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AccountPreferencesDatabase extends GeneratedDatabase {
  _$AccountPreferencesDatabase(QueryExecutor e) : super(e);
  $AccountPreferencesDatabaseManager get managers =>
      $AccountPreferencesDatabaseManager(this);
  late final $AppPreferencesTableTable appPreferencesTable =
      $AppPreferencesTableTable(this);
  late final $AppletPreferencesTableTable appletPreferencesTable =
      $AppletPreferencesTableTable(this);
  late final $AppletDataTable appletData = $AppletDataTable(this);
  late final $NotificationsDuplicatesTableTable notificationsDuplicatesTable =
      $NotificationsDuplicatesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appPreferencesTable,
    appletPreferencesTable,
    appletData,
    notificationsDuplicatesTable,
  ];
}

typedef $$AppPreferencesTableTableCreateCompanionBuilder =
    AppPreferencesTableCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$AppPreferencesTableTableUpdateCompanionBuilder =
    AppPreferencesTableCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$AppPreferencesTableTableFilterComposer
    extends Composer<_$AccountPreferencesDatabase, $AppPreferencesTableTable> {
  $$AppPreferencesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppPreferencesTableTableOrderingComposer
    extends Composer<_$AccountPreferencesDatabase, $AppPreferencesTableTable> {
  $$AppPreferencesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppPreferencesTableTableAnnotationComposer
    extends Composer<_$AccountPreferencesDatabase, $AppPreferencesTableTable> {
  $$AppPreferencesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppPreferencesTableTableTableManager
    extends
        RootTableManager<
          _$AccountPreferencesDatabase,
          $AppPreferencesTableTable,
          AppPreferencesTableData,
          $$AppPreferencesTableTableFilterComposer,
          $$AppPreferencesTableTableOrderingComposer,
          $$AppPreferencesTableTableAnnotationComposer,
          $$AppPreferencesTableTableCreateCompanionBuilder,
          $$AppPreferencesTableTableUpdateCompanionBuilder,
          (
            AppPreferencesTableData,
            BaseReferences<
              _$AccountPreferencesDatabase,
              $AppPreferencesTableTable,
              AppPreferencesTableData
            >,
          ),
          AppPreferencesTableData,
          PrefetchHooks Function()
        > {
  $$AppPreferencesTableTableTableManager(
    _$AccountPreferencesDatabase db,
    $AppPreferencesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPreferencesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPreferencesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AppPreferencesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesTableCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesTableCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppPreferencesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AccountPreferencesDatabase,
      $AppPreferencesTableTable,
      AppPreferencesTableData,
      $$AppPreferencesTableTableFilterComposer,
      $$AppPreferencesTableTableOrderingComposer,
      $$AppPreferencesTableTableAnnotationComposer,
      $$AppPreferencesTableTableCreateCompanionBuilder,
      $$AppPreferencesTableTableUpdateCompanionBuilder,
      (
        AppPreferencesTableData,
        BaseReferences<
          _$AccountPreferencesDatabase,
          $AppPreferencesTableTable,
          AppPreferencesTableData
        >,
      ),
      AppPreferencesTableData,
      PrefetchHooks Function()
    >;
typedef $$AppletPreferencesTableTableCreateCompanionBuilder =
    AppletPreferencesTableCompanion Function({
      required String appletId,
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$AppletPreferencesTableTableUpdateCompanionBuilder =
    AppletPreferencesTableCompanion Function({
      Value<String> appletId,
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$AppletPreferencesTableTableFilterComposer
    extends
        Composer<_$AccountPreferencesDatabase, $AppletPreferencesTableTable> {
  $$AppletPreferencesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get appletId => $composableBuilder(
    column: $table.appletId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppletPreferencesTableTableOrderingComposer
    extends
        Composer<_$AccountPreferencesDatabase, $AppletPreferencesTableTable> {
  $$AppletPreferencesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get appletId => $composableBuilder(
    column: $table.appletId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppletPreferencesTableTableAnnotationComposer
    extends
        Composer<_$AccountPreferencesDatabase, $AppletPreferencesTableTable> {
  $$AppletPreferencesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get appletId =>
      $composableBuilder(column: $table.appletId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppletPreferencesTableTableTableManager
    extends
        RootTableManager<
          _$AccountPreferencesDatabase,
          $AppletPreferencesTableTable,
          AppletPreferencesTableData,
          $$AppletPreferencesTableTableFilterComposer,
          $$AppletPreferencesTableTableOrderingComposer,
          $$AppletPreferencesTableTableAnnotationComposer,
          $$AppletPreferencesTableTableCreateCompanionBuilder,
          $$AppletPreferencesTableTableUpdateCompanionBuilder,
          (
            AppletPreferencesTableData,
            BaseReferences<
              _$AccountPreferencesDatabase,
              $AppletPreferencesTableTable,
              AppletPreferencesTableData
            >,
          ),
          AppletPreferencesTableData,
          PrefetchHooks Function()
        > {
  $$AppletPreferencesTableTableTableManager(
    _$AccountPreferencesDatabase db,
    $AppletPreferencesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppletPreferencesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AppletPreferencesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AppletPreferencesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> appletId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppletPreferencesTableCompanion(
                appletId: appletId,
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String appletId,
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppletPreferencesTableCompanion.insert(
                appletId: appletId,
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppletPreferencesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AccountPreferencesDatabase,
      $AppletPreferencesTableTable,
      AppletPreferencesTableData,
      $$AppletPreferencesTableTableFilterComposer,
      $$AppletPreferencesTableTableOrderingComposer,
      $$AppletPreferencesTableTableAnnotationComposer,
      $$AppletPreferencesTableTableCreateCompanionBuilder,
      $$AppletPreferencesTableTableUpdateCompanionBuilder,
      (
        AppletPreferencesTableData,
        BaseReferences<
          _$AccountPreferencesDatabase,
          $AppletPreferencesTableTable,
          AppletPreferencesTableData
        >,
      ),
      AppletPreferencesTableData,
      PrefetchHooks Function()
    >;
typedef $$AppletDataTableCreateCompanionBuilder =
    AppletDataCompanion Function({
      required String appletId,
      Value<String?> json,
      required DateTime timestamp,
      Value<int> rowid,
    });
typedef $$AppletDataTableUpdateCompanionBuilder =
    AppletDataCompanion Function({
      Value<String> appletId,
      Value<String?> json,
      Value<DateTime> timestamp,
      Value<int> rowid,
    });

class $$AppletDataTableFilterComposer
    extends Composer<_$AccountPreferencesDatabase, $AppletDataTable> {
  $$AppletDataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get appletId => $composableBuilder(
    column: $table.appletId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppletDataTableOrderingComposer
    extends Composer<_$AccountPreferencesDatabase, $AppletDataTable> {
  $$AppletDataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get appletId => $composableBuilder(
    column: $table.appletId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppletDataTableAnnotationComposer
    extends Composer<_$AccountPreferencesDatabase, $AppletDataTable> {
  $$AppletDataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get appletId =>
      $composableBuilder(column: $table.appletId, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$AppletDataTableTableManager
    extends
        RootTableManager<
          _$AccountPreferencesDatabase,
          $AppletDataTable,
          AppletDataData,
          $$AppletDataTableFilterComposer,
          $$AppletDataTableOrderingComposer,
          $$AppletDataTableAnnotationComposer,
          $$AppletDataTableCreateCompanionBuilder,
          $$AppletDataTableUpdateCompanionBuilder,
          (
            AppletDataData,
            BaseReferences<
              _$AccountPreferencesDatabase,
              $AppletDataTable,
              AppletDataData
            >,
          ),
          AppletDataData,
          PrefetchHooks Function()
        > {
  $$AppletDataTableTableManager(
    _$AccountPreferencesDatabase db,
    $AppletDataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppletDataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppletDataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppletDataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> appletId = const Value.absent(),
                Value<String?> json = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppletDataCompanion(
                appletId: appletId,
                json: json,
                timestamp: timestamp,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String appletId,
                Value<String?> json = const Value.absent(),
                required DateTime timestamp,
                Value<int> rowid = const Value.absent(),
              }) => AppletDataCompanion.insert(
                appletId: appletId,
                json: json,
                timestamp: timestamp,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppletDataTableProcessedTableManager =
    ProcessedTableManager<
      _$AccountPreferencesDatabase,
      $AppletDataTable,
      AppletDataData,
      $$AppletDataTableFilterComposer,
      $$AppletDataTableOrderingComposer,
      $$AppletDataTableAnnotationComposer,
      $$AppletDataTableCreateCompanionBuilder,
      $$AppletDataTableUpdateCompanionBuilder,
      (
        AppletDataData,
        BaseReferences<
          _$AccountPreferencesDatabase,
          $AppletDataTable,
          AppletDataData
        >,
      ),
      AppletDataData,
      PrefetchHooks Function()
    >;
typedef $$NotificationsDuplicatesTableTableCreateCompanionBuilder =
    NotificationsDuplicatesTableCompanion Function({
      required int notificationId,
      required String appletId,
      required String hash,
      required DateTime timestamp,
      Value<int> rowid,
    });
typedef $$NotificationsDuplicatesTableTableUpdateCompanionBuilder =
    NotificationsDuplicatesTableCompanion Function({
      Value<int> notificationId,
      Value<String> appletId,
      Value<String> hash,
      Value<DateTime> timestamp,
      Value<int> rowid,
    });

class $$NotificationsDuplicatesTableTableFilterComposer
    extends
        Composer<
          _$AccountPreferencesDatabase,
          $NotificationsDuplicatesTableTable
        > {
  $$NotificationsDuplicatesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appletId => $composableBuilder(
    column: $table.appletId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationsDuplicatesTableTableOrderingComposer
    extends
        Composer<
          _$AccountPreferencesDatabase,
          $NotificationsDuplicatesTableTable
        > {
  $$NotificationsDuplicatesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appletId => $composableBuilder(
    column: $table.appletId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationsDuplicatesTableTableAnnotationComposer
    extends
        Composer<
          _$AccountPreferencesDatabase,
          $NotificationsDuplicatesTableTable
        > {
  $$NotificationsDuplicatesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appletId =>
      $composableBuilder(column: $table.appletId, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$NotificationsDuplicatesTableTableTableManager
    extends
        RootTableManager<
          _$AccountPreferencesDatabase,
          $NotificationsDuplicatesTableTable,
          NotificationsDuplicatesTableData,
          $$NotificationsDuplicatesTableTableFilterComposer,
          $$NotificationsDuplicatesTableTableOrderingComposer,
          $$NotificationsDuplicatesTableTableAnnotationComposer,
          $$NotificationsDuplicatesTableTableCreateCompanionBuilder,
          $$NotificationsDuplicatesTableTableUpdateCompanionBuilder,
          (
            NotificationsDuplicatesTableData,
            BaseReferences<
              _$AccountPreferencesDatabase,
              $NotificationsDuplicatesTableTable,
              NotificationsDuplicatesTableData
            >,
          ),
          NotificationsDuplicatesTableData,
          PrefetchHooks Function()
        > {
  $$NotificationsDuplicatesTableTableTableManager(
    _$AccountPreferencesDatabase db,
    $NotificationsDuplicatesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationsDuplicatesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationsDuplicatesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationsDuplicatesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> notificationId = const Value.absent(),
                Value<String> appletId = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationsDuplicatesTableCompanion(
                notificationId: notificationId,
                appletId: appletId,
                hash: hash,
                timestamp: timestamp,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int notificationId,
                required String appletId,
                required String hash,
                required DateTime timestamp,
                Value<int> rowid = const Value.absent(),
              }) => NotificationsDuplicatesTableCompanion.insert(
                notificationId: notificationId,
                appletId: appletId,
                hash: hash,
                timestamp: timestamp,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationsDuplicatesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AccountPreferencesDatabase,
      $NotificationsDuplicatesTableTable,
      NotificationsDuplicatesTableData,
      $$NotificationsDuplicatesTableTableFilterComposer,
      $$NotificationsDuplicatesTableTableOrderingComposer,
      $$NotificationsDuplicatesTableTableAnnotationComposer,
      $$NotificationsDuplicatesTableTableCreateCompanionBuilder,
      $$NotificationsDuplicatesTableTableUpdateCompanionBuilder,
      (
        NotificationsDuplicatesTableData,
        BaseReferences<
          _$AccountPreferencesDatabase,
          $NotificationsDuplicatesTableTable,
          NotificationsDuplicatesTableData
        >,
      ),
      NotificationsDuplicatesTableData,
      PrefetchHooks Function()
    >;

class $AccountPreferencesDatabaseManager {
  final _$AccountPreferencesDatabase _db;
  $AccountPreferencesDatabaseManager(this._db);
  $$AppPreferencesTableTableTableManager get appPreferencesTable =>
      $$AppPreferencesTableTableTableManager(_db, _db.appPreferencesTable);
  $$AppletPreferencesTableTableTableManager get appletPreferencesTable =>
      $$AppletPreferencesTableTableTableManager(
        _db,
        _db.appletPreferencesTable,
      );
  $$AppletDataTableTableManager get appletData =>
      $$AppletDataTableTableManager(_db, _db.appletData);
  $$NotificationsDuplicatesTableTableTableManager
  get notificationsDuplicatesTable =>
      $$NotificationsDuplicatesTableTableTableManager(
        _db,
        _db.notificationsDuplicatesTable,
      );
}
