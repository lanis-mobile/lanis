import 'package:native_dio_adapter/native_dio_adapter.dart';

NativeAdapter getNativeAdapterInstance() {
  return NativeAdapter(createCronetEngine: () {
    return CronetEngine.build(
      enableHttp2: true,
      enableBrotli: true,
    );
  });
}
