import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

HttpClientAdapter? _cachedNativeAdapter;
CronetEngine? _cachedCronetEngine;

HttpClientAdapter getHttpClientAdapter() {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return IOHttpClientAdapter();
  }
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
