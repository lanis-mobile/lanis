import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

/// Mounted by the authenticated shell only. Interface availability never proves
/// authentication or server reachability; recovery still probes the server.
final networkInterfaceAvailableProvider =
    NotifierProvider<NetworkInterfaceAvailable, bool?>(
      NetworkInterfaceAvailable.new,
    );

class NetworkInterfaceAvailable extends Notifier<bool?> {
  @override
  bool? build() => null;
  void update(bool available) => state = available;
}

final foregroundConnectionMonitorProvider = Provider.autoDispose<void>((ref) {
  final monitor = _ForegroundConnectionMonitor(
    ref.read(connectionCheckerProvider),
    (available) =>
        ref.read(networkInterfaceAvailableProvider.notifier).update(available),
  );
  monitor.start();
  ref.onDispose(monitor.dispose);
});

class _ForegroundConnectionMonitor with WidgetsBindingObserver {
  final ConnectionChecker checker;
  final Connectivity connectivity = Connectivity();
  final void Function(bool) onAvailability;
  StreamSubscription<List<ConnectivityResult>>? subscription;
  StreamSubscription<ConnectionStatus>? serverSubscription;
  Timer? retry;
  bool active = true;
  bool? hadInterface;
  bool disposed = false;
  bool probing = false;
  _ForegroundConnectionMonitor(this.checker, this.onAvailability);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    subscription = connectivity.onConnectivityChanged.listen(
      _changed,
      onError: (Object _) {},
    );
    serverSubscription = checker.statusStream.listen((status) {
      if (status == ConnectionStatus.connected) {
        retry?.cancel();
      } else {
        _scheduleRetry();
      }
    });
    unawaited(_check());
  }

  Future<void> _check() async {
    try {
      _changed(await connectivity.checkConnectivity());
    } catch (_) {
      // Unsupported test/platform channels must not affect working HTTP reads.
    }
  }

  void _changed(List<ConnectivityResult> values) {
    if (disposed) return;
    final available = values.any((value) => value != ConnectivityResult.none);
    onAvailability(available);
    final previous = hadInterface;
    hadInterface = available;
    if (!available) {
      retry?.cancel();
      checker.status = ConnectionStatus.disconnected;
    } else if ((previous == false ||
            checker.status == ConnectionStatus.disconnected) &&
        !probing) {
      unawaited(_probe());
    }
  }

  Future<void> _probe() async {
    if (disposed || !active || probing || hadInterface != true) return;
    probing = true;
    try {
      await checker.testConnection();
    } finally {
      probing = false;
      if (!disposed && hadInterface == false) {
        checker.status = ConnectionStatus.disconnected;
      }
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    retry?.cancel();
    if (disposed ||
        !active ||
        hadInterface != true ||
        checker.status == ConnectionStatus.connected) {
      return;
    }
    retry = Timer(const Duration(seconds: 30), () => unawaited(_probe()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      unawaited(_check());
    } else {
      retry?.cancel();
    }
  }

  void dispose() {
    disposed = true;
    subscription?.cancel();
    serverSubscription?.cancel();
    retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
