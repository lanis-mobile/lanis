import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

HttpClientAdapter? _cachedAdapter;
CronetEngine? _cachedCronetEngine;

HttpClientAdapter getNativeAdapterInstance() {
  if (_cachedAdapter != null) return _cachedAdapter!;

  try {
    _cachedAdapter = NativeAdapter(
      createCronetEngine: () {
        _cachedCronetEngine ??= CronetEngine.build(
          enableHttp2: true,
          enableBrotli: true,
          enableQuic: true,
        );
        return _cachedCronetEngine!;
      },
    );
  } catch (e) {
    _cachedAdapter = IOHttpClientAdapter();
  }

  return _cachedAdapter!;
}
