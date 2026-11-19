import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/offline/cached_data_source.dart';

MaybeCacheResult<int> saved({DateTime? expiresAt}) => MaybeCacheResult(
  data: 42,
  cacheStatus: CacheStatus.cache,
  fetchedAt: DateTime.now().subtract(const Duration(days: 2)),
  responseAt: DateTime.now(),
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 5)),
);

void main() {
  test('cache-only preview is read once without a second read', () async {
    var cacheReads = 0;
    var secondaryReads = 0;
    final source = CachedDataSource<int>(
      cacheOnly: true,
      readCache: () async {
        cacheReads++;
        return saved();
      },
      read: () async {
        secondaryReads++;
        return saved();
      },
    );
    addTearDown(source.dispose);
    await source.fetchData();
    expect(source.latestResponse.content, 42);
    expect(cacheReads, 1);
    expect(secondaryReads, 0);
  });

  test('a cache-only miss does not repeat the failed lookup', () async {
    var reads = 0;
    final source = CachedDataSource<int>(
      cacheOnly: true,
      readCache: () async =>
          throw CacheUnavailableException(CacheEntryState.missing),
      read: () async {
        reads++;
        return saved();
      },
    );
    addTearDown(source.dispose);
    await source.fetchData();
    expect(
      source.latestResponse.error?.exception,
      isA<CacheUnavailableException>(),
    );
    expect(reads, 0);
  });

  test('prepared data is available before the first frame', () {
    final source = CachedDataSource<int>(
      initial: saved(),
      cacheOnly: true,
      read: () async => saved(),
    );
    addTearDown(source.dispose);
    expect(source.latestResponse.status, FetcherStatus.done);
    expect(source.latestResponse.content, 42);
  });

  test(
    'shows saved data during a pending refresh and keeps it on transport failure',
    () async {
      final request = Completer<MaybeCacheResult<int>>();
      final value = saved();
      final source = CachedDataSource(
        read: () => request.future,
        readCache: () async => value,
      );
      addTearDown(source.dispose);
      final fetch = source.fetchData();
      await Future<void>.delayed(Duration.zero);
      expect(source.latestResponse.content, 42);
      expect(source.latestResponse.contentStatus, ContentStatus.offline);
      request.completeError(NoConnectionException());
      await fetch;
      expect(source.latestResponse.status, FetcherStatus.done);
      expect(source.latestResponse.content, 42);
      expect(source.latestResponse.fetchedAt, value.fetchedAt);
      expect(source.latestResponse.expiresAt, value.expiresAt);
    },
  );

  for (final failure in [
    WrongCredentialsException(),
    const FormatException('invalid HTML'),
  ]) {
    test('does not hide ${failure.runtimeType} behind saved data', () async {
      final source = CachedDataSource<int>(
        readCache: () async => saved(),
        read: () async => throw failure,
      );
      addTearDown(source.dispose);
      await source.fetchData();
      expect(source.latestResponse.status, FetcherStatus.error);
      expect(source.latestResponse.content, isNull);
      expect(source.latestResponse.error!.exception, same(failure));
    });
  }

  test('late refresh completions cannot replace a newer result', () async {
    final first = Completer<MaybeCacheResult<int>>();
    final second = Completer<MaybeCacheResult<int>>();
    var count = 0;
    final source = CachedDataSource<int>(
      read: () => ++count == 1 ? first.future : second.future,
    );
    addTearDown(source.dispose);
    final a = source.fetchData();
    final b = source.fetchData(forceRefresh: true);
    second.complete(saved().map((_) => 2));
    await b;
    first.completeError(NoConnectionException());
    await a;
    expect(source.latestResponse.content, 2);
  });

  test(
    'disposing during cache lookup does not start a later HTTP read',
    () async {
      final cached = Completer<MaybeCacheResult<int>>();
      var reads = 0;
      final source = CachedDataSource<int>(
        readCache: () => cached.future,
        read: () async {
          reads++;
          return saved();
        },
      );
      final fetch = source.fetchData();
      source.dispose();
      cached.completeError(CacheUnavailableException(CacheEntryState.missing));
      await fetch;
      expect(reads, 0);
    },
  );

  test(
    'a newer supplied home result cancels the pending cache preview',
    () async {
      final cached = Completer<MaybeCacheResult<int>>();
      var reads = 0;
      final source = CachedDataSource<int>(
        readCache: () => cached.future,
        read: () async {
          reads++;
          return saved();
        },
      );
      addTearDown(source.dispose);
      final fetch = source.fetchData();
      source.updateResult(saved().map((_) => 99));
      cached.completeError(CacheUnavailableException(CacheEntryState.missing));
      await fetch;
      expect(reads, 0);
      expect(source.latestResponse.content, 99);
    },
  );

  testWidgets(
    'an old fallback retries at the cadence without an immediate timer loop',
    (tester) async {
      var count = 0;
      final source = CachedDataSource<int>(
        read: () async {
          count++;
          return saved();
        },
        refreshInterval: const Duration(minutes: 10),
      );
      source.startAutoRefresh();
      await source.fetchData();
      await tester.pump(const Duration(seconds: 1));
      expect(count, 1);
      await tester.pump(const Duration(minutes: 10));
      expect(count, 2);
      source.dispose();
    },
  );

  testWidgets('explicit offline browsing never starts refresh polling', (
    tester,
  ) async {
    var count = 0;
    final source = CachedDataSource<int>(
      cacheOnly: true,
      read: () async {
        count++;
        return saved();
      },
      refreshInterval: const Duration(minutes: 10),
    );
    source.startAutoRefresh();
    await source.fetchData();
    await tester.pump(const Duration(hours: 2));
    expect(count, 1);
    source.dispose();
  });
}
