import 'dart:io';

import 'package:liblanis/liblanis.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import 'flutter_secret_store.dart';

/// Secure-storage key used by the pre-v4 Drift stack for AES password wrapping.
const legacyV3EncryptionKeyName = 'encryption_key';

final _sessionDbName = RegExp(r'^session_\d+_db');
final _numericDirName = RegExp(r'^\d+$');

/// Whether [fileName] is a leftover v3 Drift SQLite file (including sidecars).
bool isLegacyV3SqliteFileName(String fileName) {
  if (fileName.startsWith('accounts_database')) return true;
  return _sessionDbName.hasMatch(fileName);
}

/// Removes orphaned v3 Drift DBs, old document-cache trees, and `encryption_key`.
///
/// Leaves v4 `lanis.db`, `account_password_*`, and `lanis_documents/` untouched.
/// Safe to call on every startup; a no-op once artifacts are gone.
Future<void> removeLegacyV3StorageArtifacts({
  SecretStore? store,
  Directory? cacheDirectory,
  Directory? documentsDirectory,
  Directory? temporaryDirectory,
}) async {
  final cache = cacheDirectory ?? await getApplicationCacheDirectory();
  final documents =
      documentsDirectory ?? await getApplicationDocumentsDirectory();
  final temporary = temporaryDirectory ?? await getTemporaryDirectory();
  final secretStore = store ?? FlutterSecretStore();

  var removed = 0;

  for (final dir in [cache, documents]) {
    removed += await _deleteLegacySqliteIn(dir);
  }
  removed += await _deleteLegacyDocumentCaches(temporary);

  try {
    final existing = await secretStore.read(legacyV3EncryptionKeyName);
    if (existing != null) {
      await secretStore.delete(legacyV3EncryptionKeyName);
      removed++;
    }
  } catch (e) {
    logger.e('Failed to delete legacy encryption_key: $e');
  }

  if (removed > 0) {
    logger.i('Removed $removed legacy v3 storage artifact(s)');
  }
}

Future<int> _deleteLegacySqliteIn(Directory dir) async {
  if (!dir.existsSync()) return 0;
  var removed = 0;
  try {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      if (!isLegacyV3SqliteFileName(p.basename(entity.path))) continue;
      try {
        await entity.delete();
        removed++;
      } catch (e) {
        logger.e('Failed to delete legacy DB ${entity.path}: $e');
      }
    }
  } catch (e) {
    logger.e('Failed to scan ${dir.path} for legacy DBs: $e');
  }
  return removed;
}

Future<int> _deleteLegacyDocumentCaches(Directory temporary) async {
  if (!temporary.existsSync()) return 0;
  var removed = 0;
  try {
    for (final entity in temporary.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      final basename = p.basename(entity.path);
      if (!_numericDirName.hasMatch(basename)) continue;
      final documentCache = Directory(p.join(entity.path, 'document_cache'));
      if (!documentCache.existsSync()) continue;
      try {
        await entity.delete(recursive: true);
        removed++;
      } catch (e) {
        logger.e('Failed to delete legacy document cache ${entity.path}: $e');
      }
    }
  } catch (e) {
    logger.e('Failed to scan ${temporary.path} for legacy document caches: $e');
  }
  return removed;
}
