import 'dart:async';
import 'package:dio/dio.dart';
import 'package:lanis/core/native_adapter_instance.dart';

CustomConnectionChecker connectionChecker = CustomConnectionChecker();

enum ConnectionStatus { connected, disconnected }

class CustomConnectionChecker {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  late final Dio dio;
  DateTime lastRequest = DateTime.now().subtract(const Duration(seconds: 5));

  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  CustomConnectionChecker() {
    dio = Dio(BaseOptions(validateStatus: (status) => status != null));
    dio.httpClientAdapter = getNativeAdapterInstance();

    testConnection();
  }

  set status(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
    lastRequest = DateTime.now();
  }

  ConnectionStatus get status => _status;

  Future<bool> _isConnected() async {
    if (DateTime.now().difference(lastRequest) > const Duration(seconds: 1)) {
      await testConnection();
    }
    return _status == ConnectionStatus.connected;
  }

  Future<bool> get connected async => await _isConnected();

  void dispose() {
    _statusController.close();
  }

  Future<bool> testConnection() async {
    try {
      await dio.post("https://start.schulportal.hessen.de/ajax_login.php");
      status = ConnectionStatus.connected;
      return true;
    } catch (e) {
      status = ConnectionStatus.disconnected;
      return false;
    }
  }
}
