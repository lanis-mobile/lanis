import 'package:colored_logger/colored_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class Logger {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final String? _name;

  Logger([this._name]);

  void i(dynamic message) {
    if (kDebugMode) {
      ColoredLogger.info(
        message.toString(),
        prefix: '${_dateFormat.format(DateTime.now())}    [INFO] $_name: ',
      );
    }
  }

  void e(dynamic message, {StackTrace? stackTrace}) {
    if (kDebugMode) {
      ColoredLogger.error(
        message.toString(),
        prefix: '${_dateFormat.format(DateTime.now())}   [ERROR] $_name: ',
      );
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace, label: _name);
      }
    }
  }

  void w(dynamic message) {
    if (kDebugMode) {
      ColoredLogger.warning(
        message.toString(),
        prefix: '${_dateFormat.format(DateTime.now())} [WARNING] $_name: ',
      );
    }
  }

  void d(dynamic message) {
    if (kDebugMode) {
      // Info but bold;
      ColoredLogger.colorize(
        message.toString(),
        prefix: '${_dateFormat.format(DateTime.now())}   [DEBUG] $_name: ',
        styles: [Ansi.bold, Ansi.brightBlue],
      );
    }
  }

  void testLogger() {
    i('This is an info message');
    e('This is an error message');
    w('This is a warning message');
    d('This is a debug message');
  }
}

class MemoryLogger {
  StringBuffer logs = StringBuffer();

  void log(String message) {
    logs.write('${DateTime.now().toIso8601String().split(".")[0]}| $message\n');
  }

  void write(String message) {
    logs.write('$message\n');
  }
}

Logger logger = Logger('Lanis');
Logger backgroundLogger = Logger('Lanis BG');
