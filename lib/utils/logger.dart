import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class Logger {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final String? _name;

  Logger([this._name]);

  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';

  void i(dynamic message) {
    if (kDebugMode) {
      print(
          '$_blue${_dateFormat.format(DateTime.now())} [INFO] $_name: $message$_reset');
    }
  }

  void e(dynamic message, {StackTrace? stackTrace}) {
    if (kDebugMode) {
      print(
          '$_red${_dateFormat.format(DateTime.now())} [ERROR] $_name: $message$_reset');
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace, label: _name);
      }
    }
  }

  void w(dynamic message) {
    if (kDebugMode) {
      print(
          '$_yellow${_dateFormat.format(DateTime.now())} [WARNING] $_name: $message$_reset');
    }
  }

  void f(dynamic message) {
    if (kDebugMode) {
      print(
          '$_magenta${_dateFormat.format(DateTime.now())} [FATAL] $_name: $message$_reset');
    }
  }

  void d(dynamic message) {
    if (kDebugMode) {
      print(
          '$_magenta${_dateFormat.format(DateTime.now())} [DEBUG] $_name: $message$_reset');
    }
  }

  void database(String message) {
    if (kDebugMode) {
      print(
          '$_cyan${_dateFormat.format(DateTime.now())} [DATABASE] $_name: $message$_reset');
    }
  }
}

class MemoryLogger {
  String logs = '';

  void log(String message) {
    logs += '${DateTime.now().toIso8601String().split(".")[0]}| $message\n';
  }

  void write(String message) {
    logs += message += '\n';
  }
}

Logger logger = Logger('Lanis');
Logger backgroundLogger = Logger('Lanis Background');
