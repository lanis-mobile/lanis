import 'package:native_dio_adapter/native_dio_adapter.dart';

NativeAdapter? _cachedNativeAdapter;
CronetEngine? _cachedCronetEngine;

NativeAdapter getNativeAdapterInstance() {
  if (_cachedNativeAdapter != null) return _cachedNativeAdapter!;
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
  return _cachedNativeAdapter!;
}
