import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:liblanis/liblanis.dart';

/// [SecretStore] backed by [FlutterSecureStorage].
class FlutterSecretStore implements SecretStore {
  FlutterSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}
