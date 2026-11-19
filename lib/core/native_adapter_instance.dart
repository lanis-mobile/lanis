import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

HttpClientAdapter? _cachedNativeAdapter;
CronetEngine? _cachedCronetEngine;

HttpClientAdapter getNativeAdapterInstance() {
  if (_cachedNativeAdapter != null) return _cachedNativeAdapter!;
  try {
    _cachedNativeAdapter = NativeAdapter(
      createCronetEngine: () {
        _cachedCronetEngine ??= CronetEngine.build(
          enableHttp2: true,
          enableBrotli: true,
          enableQuic: true,
        );
        return _cachedCronetEngine!;
      },
    );
  } catch (_) {
    // Devices without an enabled Cronet provider still need a working client.
    _cachedNativeAdapter = IOHttpClientAdapter();
  }
  return _cachedNativeAdapter!;
}
