import 'dart:async';

import 'package:liblanis/liblanis.dart';

/// Presents result metadata using the app's existing stream contract.
/// Offline routes supply a read closure which only accesses the local cache.
class CachedDataSource<T> implements AppletDataSource<T> {
  final Future<MaybeCacheResult<T>> Function() read;
  final bool cacheOnly;
  final Future<MaybeCacheResult<T>> Function()? readCache;
  final Duration? refreshInterval;
  MaybeCacheResult<T>? _initial;
  final _controller = StreamController<FetcherResponse<T>>.broadcast();
  FetcherResponse<T> _latest = FetcherResponse(
    status: FetcherStatus.fetching,
    error: null,
  );
  bool _active = false;
  bool _disposed = false;
  Timer? _expiry;
  int _revision = 0;

  CachedDataSource({
    required this.read,
    this.cacheOnly = false,
    this.readCache,
    this.refreshInterval,
    MaybeCacheResult<T>? initial,
  }) : _initial = initial {
    if (initial != null && DateTime.now().isBefore(initial.expiresAt)) {
      _deliver(initial);
    }
  }
  @override
  Stream<FetcherResponse<T>> get stream => _controller.stream;
  @override
  FetcherResponse<T> get latestResponse => _latest;
  void _publish(FetcherResponse<T> value) {
    if (_disposed) return;
    _latest = value;
    _controller.add(value);
  }

  @override
  void startAutoRefresh() {
    _active = true;
    _scheduleExpiry();
  }

  @override
  void stopAutoRefresh() {
    _active = false;
    _expiry?.cancel();
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    final expiry = _latest.expiresAt;
    if (!_active || expiry == null || _disposed) return;
    final now = DateTime.now();
    final nextRefresh = !cacheOnly && refreshInterval != null
        ? now.add(refreshInterval!)
        : expiry;
    final next = nextRefresh.isBefore(expiry) ? nextRefresh : expiry;
    final delay = next.difference(now);
    _expiry = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => fetchData(forceRefresh: true),
    );
  }

  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    if (_disposed) return;
    final previous = _latest;
    final revision = ++_revision;
    final expiry = _latest.expiresAt;
    if (expiry != null && !DateTime.now().isBefore(expiry)) {
      _publish(FetcherResponse(status: FetcherStatus.fetching, error: null));
    }
    try {
      final initial = _initial;
      _initial = null;
      if (initial == null && _latest.content == null && readCache != null) {
        try {
          final cached = await readCache!();
          if (_disposed || revision != _revision) return;
          _deliver(cached);
          if (cacheOnly) return;
        } catch (_) {
          if (cacheOnly) rethrow;
          // A cache miss must not prevent an online request or change its error.
        }
      }
      if (_disposed || revision != _revision) return;
      final result =
          initial != null &&
              !forceRefresh &&
              DateTime.now().isBefore(initial.expiresAt)
          ? initial
          : await read();
      if (_disposed || revision != _revision) return;
      _deliver(result);
    } catch (error, stack) {
      if (_disposed || revision != _revision) return;
      _expiry?.cancel();
      final fallback = _latest.content != null ? _latest : previous;
      if (CacheService.isTransportFailure(error) &&
          fallback.content != null &&
          (fallback.expiresAt?.isAfter(DateTime.now()) ?? false)) {
        _publish(
          FetcherResponse(
            status: FetcherStatus.done,
            content: fallback.content,
            contentStatus: ContentStatus.offline,
            fetchedAt: fallback.fetchedAt,
            responseAt: DateTime.now(),
            expiresAt: fallback.expiresAt,
            error: ExceptionWithStackTrace(exception: error, stackTrace: stack),
          ),
        );
        _scheduleExpiry();
        return;
      }
      _publish(
        FetcherResponse(
          status: FetcherStatus.error,
          contentStatus:
              cacheOnly ||
                  error is CacheUnavailableException ||
                  CacheService.isTransportFailure(error)
              ? ContentStatus.offline
              : ContentStatus.online,
          error: ExceptionWithStackTrace(exception: error, stackTrace: stack),
        ),
      );
    }
  }

  /// Accept an already fetched parent-home result without another HTTP read.
  void updateResult(MaybeCacheResult<T> result) {
    if (_disposed) return;
    ++_revision;
    _initial = null;
    _deliver(result);
  }

  void _deliver(MaybeCacheResult<T> result) {
    if (!DateTime.now().isBefore(result.expiresAt)) {
      throw CacheUnavailableException(CacheEntryState.expired);
    }
    _publish(
      FetcherResponse(
        status: FetcherStatus.done,
        error: null,
        content: result.data,
        contentStatus: result.cacheStatus == CacheStatus.cache
            ? ContentStatus.offline
            : ContentStatus.online,
        fetchedAt: result.fetchedAt,
        responseAt: result.responseAt,
        expiresAt: result.expiresAt,
      ),
    );
    _scheduleExpiry();
  }

  void dispose() {
    stopAutoRefresh();
    _disposed = true;
    _controller.close();
  }
}
