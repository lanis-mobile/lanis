import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

CronetEngine? _cachedCronetEngine;
HttpClientAdapter? _cachedAdapter;

HttpClientAdapter getNativeAdapterInstance() {
  _cachedAdapter ??= _FallbackAdapter();
  return _cachedAdapter!;
}

class _FallbackAdapter implements HttpClientAdapter {
  HttpClientAdapter? _native;
  HttpClientAdapter? _fallback;
  bool _useFallback = false;

  HttpClientAdapter get _active {
    if (_useFallback) return _fallback ??= HttpClientAdapter();
    _native ??= NativeAdapter(
      createCronetEngine: () {
        _cachedCronetEngine ??= CronetEngine.build(
          enableHttp2: true,
          enableBrotli: true,
          enableQuic: true,
        );
        return _cachedCronetEngine!;
      },
    );
    return _native!;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    try {
      return await _active.fetch(options, requestStream, cancelFuture);
    } catch (e) {
      if (!_useFallback && _isNativeAdapterFailure(e)) {
        _useFallback = true;
        return await (_fallback ??= HttpClientAdapter())
            .fetch(options, requestStream, cancelFuture);
      }
      rethrow;
    }
  }

  static bool _isNativeAdapterFailure(Object e) {
    final msg = e.toString();
    return msg.contains('native_cupertino_bindings') ||
        msg.contains('MissingPluginException') ||
        msg.contains('CronetEngine') ||
        (e is Error && e is! AssertionError);
  }

  @override
  void close({bool force = false}) {
    _native?.close(force: force);
    _fallback?.close(force: force);
  }
}
