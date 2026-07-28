import 'package:liblanis/liblanis.dart';

/// Load one applet setting using the default value's type as the source of truth.
///
/// Avoids probing every typed getter: an accidental `Map.toString()` string
/// would otherwise be read as `false` via [TypedSettings.getBool].
dynamic resolveStoredAppletSetting(
  TypedSettings settings,
  String namespacedKey,
  dynamic defaultValue,
) {
  if (defaultValue is Map) {
    final map = settings.getJsonMap(namespacedKey);
    if (map != null) return map;
    // Drop corrupted non-map leftovers (e.g. `{key: value}` from Map.toString()).
    if (settings.getString(namespacedKey) != null) {
      settings.remove(namespacedKey);
    }
    return Map<String, dynamic>.from(defaultValue);
  }
  if (defaultValue is List) {
    return settings.getJsonList(namespacedKey) ??
        List<dynamic>.from(defaultValue);
  }
  if (defaultValue is bool) {
    return settings.getBool(namespacedKey) ?? defaultValue;
  }
  if (defaultValue is int) {
    return settings.getInt(namespacedKey) ?? defaultValue;
  }
  if (defaultValue is double) {
    return settings.getDouble(namespacedKey) ?? defaultValue;
  }
  if (defaultValue is String) {
    return settings.getString(namespacedKey) ?? defaultValue;
  }

  return settings.getJsonMap(namespacedKey) ??
      settings.getJsonList(namespacedKey) ??
      settings.getBool(namespacedKey) ??
      settings.getInt(namespacedKey) ??
      settings.getString(namespacedKey) ??
      defaultValue;
}

/// Persist an applet setting with robust Map/List handling.
void persistAppletSetting(
  TypedSettings settings,
  String namespacedKey,
  dynamic value,
) {
  if (value is bool) {
    settings.setBool(namespacedKey, value);
  } else if (value is int) {
    settings.setInt(namespacedKey, value);
  } else if (value is double) {
    settings.setDouble(namespacedKey, value);
  } else if (value is String) {
    settings.setString(namespacedKey, value);
  } else if (value is Map) {
    // Cast via [Map.from]: callers often pass `Map<String, String>` /
    // `Map<String, String?>` literals that fail `is Map<String, dynamic>`.
    settings.setJsonMap(namespacedKey, Map<String, dynamic>.from(value));
  } else if (value is List) {
    settings.setJsonList(namespacedKey, value);
  } else if (value == null) {
    settings.remove(namespacedKey);
  } else {
    settings.setString(namespacedKey, value.toString());
  }
}
