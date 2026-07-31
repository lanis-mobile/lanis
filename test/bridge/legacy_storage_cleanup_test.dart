import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/bridge/legacy_storage_cleanup.dart';
import 'package:liblanis/liblanis.dart';
import 'package:path/path.dart' as p;

void main() {
  group('isLegacyV3SqliteFileName', () {
    test('matches accounts_database and session_*_db including sidecars', () {
      expect(isLegacyV3SqliteFileName('accounts_database.sqlite'), isTrue);
      expect(isLegacyV3SqliteFileName('accounts_database.sqlite-wal'), isTrue);
      expect(isLegacyV3SqliteFileName('accounts_database.sqlite-shm'), isTrue);
      expect(isLegacyV3SqliteFileName('session_1_db.sqlite'), isTrue);
      expect(isLegacyV3SqliteFileName('session_42_db.sqlite-wal'), isTrue);
    });

    test('ignores v4 and unrelated names', () {
      expect(isLegacyV3SqliteFileName('lanis.db'), isFalse);
      expect(isLegacyV3SqliteFileName('lanis.db-wal'), isFalse);
      expect(isLegacyV3SqliteFileName('session_db.sqlite'), isFalse);
      expect(isLegacyV3SqliteFileName('other.sqlite'), isFalse);
    });
  });

  group('removeLegacyV3StorageArtifacts', () {
    late Directory root;
    late Directory cache;
    late Directory documents;
    late Directory temporary;
    late MemorySecretStore store;

    setUp(() {
      root = Directory.systemTemp.createTempSync('legacy_v3_cleanup_');
      cache = Directory(p.join(root.path, 'cache'))..createSync();
      documents = Directory(p.join(root.path, 'documents'))..createSync();
      temporary = Directory(p.join(root.path, 'temp'))..createSync();
      store = MemorySecretStore();
    });

    tearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    Future<void> touch(Directory dir, String name) async {
      File(p.join(dir.path, name)).writeAsStringSync('x');
    }

    test('deletes legacy DBs and encryption_key; keeps v4 artifacts', () async {
      await touch(cache, 'accounts_database.sqlite');
      await touch(cache, 'session_1_db.sqlite-wal');
      await touch(cache, 'lanis.db');
      await touch(documents, 'session_2_db.sqlite');

      final legacyDocs = Directory(p.join(temporary.path, '9', 'document_cache'))
        ..createSync(recursive: true);
      File(p.join(legacyDocs.path, 'file.bin')).writeAsStringSync('old');

      final v4Docs = Directory(
        p.join(temporary.path, 'lanis_documents', '1', 'document_cache'),
      )..createSync(recursive: true);
      File(p.join(v4Docs.path, 'keep.bin')).writeAsStringSync('new');

      await store.write(legacyV3EncryptionKeyName, 'old-aes-key');
      await store.write('account_password_1', 'secret');

      await removeLegacyV3StorageArtifacts(
        store: store,
        cacheDirectory: cache,
        documentsDirectory: documents,
        temporaryDirectory: temporary,
      );

      expect(File(p.join(cache.path, 'accounts_database.sqlite')).existsSync(), isFalse);
      expect(File(p.join(cache.path, 'session_1_db.sqlite-wal')).existsSync(), isFalse);
      expect(File(p.join(documents.path, 'session_2_db.sqlite')).existsSync(), isFalse);
      expect(Directory(p.join(temporary.path, '9')).existsSync(), isFalse);

      expect(File(p.join(cache.path, 'lanis.db')).existsSync(), isTrue);
      expect(
        File(p.join(v4Docs.path, 'keep.bin')).existsSync(),
        isTrue,
      );
      expect(await store.read(legacyV3EncryptionKeyName), isNull);
      expect(await store.read('account_password_1'), 'secret');
    });

    test('is a no-op when nothing legacy remains', () async {
      await touch(cache, 'lanis.db');
      await store.write('account_password_1', 'secret');

      await removeLegacyV3StorageArtifacts(
        store: store,
        cacheDirectory: cache,
        documentsDirectory: documents,
        temporaryDirectory: temporary,
      );

      expect(File(p.join(cache.path, 'lanis.db')).existsSync(), isTrue);
      expect(await store.read('account_password_1'), 'secret');
    });
  });
}
