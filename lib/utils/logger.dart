import 'package:colored_logger/colored_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class Logger {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final String? _name;
  final int _maxHistorySize;
  final List<String> _history = [];

  Logger(this._name, {int maxHistorySize = 100})
    : _maxHistorySize = maxHistorySize;

  void _addToHistory(String message) {
    _history.add(message);
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
  }

  void i(dynamic message) {
    if (kDebugMode) {
      final msg = message.toString();
      ColoredLogger.info(
        msg,
        prefix: '${_dateFormat.format(DateTime.now())}    [INFO] $_name: ',
      );
      _addToHistory('[INFO] $msg');
    }
  }

  void e(dynamic message, {StackTrace? stackTrace}) {
    if (kDebugMode) {
      final msg = message.toString();
      ColoredLogger.error(
        msg,
        prefix: '${_dateFormat.format(DateTime.now())}   [ERROR] $_name: ',
      );
      _addToHistory('[ERROR] $msg');
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace, label: _name);
        _addToHistory('[STACKTRACE] $stackTrace');
      }
    }
  }

  void w(dynamic message) {
    if (kDebugMode) {
      final msg = message.toString();
      ColoredLogger.warning(
        msg,
        prefix: '${_dateFormat.format(DateTime.now())} [WARNING] $_name: ',
      );
      _addToHistory('[WARNING] $msg');
    }
  }

  void d(dynamic message) {
    if (kDebugMode) {
      final msg = message.toString();
      ColoredLogger.colorize(
        msg,
        prefix: '${_dateFormat.format(DateTime.now())}   [DEBUG] $_name: ',
        styles: [Ansi.bold, Ansi.brightBlue],
      );
      _addToHistory('[DEBUG] $msg');
    }
  }

  String getHistory() => _history.join("\n");

  void clearHistory() => _history.clear();

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

Logger logger = Logger('Lanis', maxHistorySize: 100);
Logger backgroundLogger = Logger('Lanis BG', maxHistorySize: 0);
