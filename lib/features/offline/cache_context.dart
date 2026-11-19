import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:path/path.dart' as p;

/// Local account identity and storage only. This is not an authenticated session.
class OfflineCacheContext {
  final AccountSummary account;
  final CacheService cache;
  final TypedSettings settings;
  final LanisConfig config;
  const OfflineCacheContext({
    required this.account,
    required this.cache,
    required this.settings,
    required this.config,
  });

  Future<MaybeCacheResult<T>> read<T>(CacheRequest<T> request) =>
      cache.readCacheFor(accountId: account.localId, request: request);

  String? cachedDocument(String url, String filename) {
    final root = config.documentCacheDirectory;
    if (root == null || !config.storageEnabled) return null;
    final hash = sha256.convert(utf8.encode(url)).toString().substring(0, 12);
    final path = p.join(
      root,
      '${account.localId}',
      'document_cache',
      hash,
      filename,
    );
    return File(path).existsSync() ? path : null;
  }
}

final offlineCacheContextProvider = Provider<OfflineCacheContext?>(
  (ref) => null,
);
