import 'package:flutter/material.dart';

class KeyboardObserver extends ValueNotifier<KeyboardStatus>
    with WidgetsBindingObserver {
  KeyboardObserver({
    KeyboardStatus value = KeyboardStatus.unknown,
  }) : super(KeyboardStatus.unknown);

  bool _disposed = false;

  void update() {
    if (_disposed) {
      return;
    }

    final view = WidgetsBinding.instance.platformDispatcher.views.first;

    if (view.viewInsets.bottom > 0.0) {
      value = KeyboardStatus.opened;
    } else {
      value = KeyboardStatus.closed;
    }
  }

  /// Unfocus a text node (Removes the cursor).
  void addDefaultCallback() {
    addListener(() {
      if (value == KeyboardStatus.closed) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    update();
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) {
      WidgetsBinding.instance.addObserver(this);
    }
    if (value == KeyboardStatus.unknown) {
      update();
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!_disposed && !hasListeners) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    super.dispose();
  }
}

enum KeyboardStatus {
  closed,
  opened,
  unknown,
}
