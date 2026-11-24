import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/router.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:liblanis/liblanis.dart';

/// Validates and normalizes a notification redirect target to an internal
/// `go_router` path under a valid Lanis applet or common prefix.
String? normalizeNotificationRedirectUri(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('/')) {
    if (trimmed.startsWith('//')) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.hasScheme || parsed.hasAuthority) {
      return null;
    }
    if (deepLinkPrefixOf(trimmed) == null) {
      return null;
    }
    return trimmed;
  }

  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || parsed.scheme != 'lanis') {
    return null;
  }
  final normalized = deepLinkLocationFromUri(parsed);
  if (normalized == null || deepLinkPrefixOf(normalized) == null) {
    return null;
  }
  return normalized;
}

/// Structured payload stored on local notifications for route navigation.
class NotificationNavigationPayload {
  final String redirectUri;
  final int? accountId;

  const NotificationNavigationPayload({
    required this.redirectUri,
    this.accountId,
  });

  Map<String, dynamic> toJson() => {
    'redirectUri': redirectUri,
    if (accountId != null) 'accountId': accountId,
  };

  String encode() => jsonEncode(toJson());

  static NotificationNavigationPayload? tryParse(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) {
        return null;
      }
      final rawRedirect = decoded['redirectUri'];
      if (rawRedirect is! String) {
        return null;
      }
      final redirectUri = normalizeNotificationRedirectUri(rawRedirect);
      if (redirectUri == null) {
        return null;
      }
      final rawAccountId = decoded['accountId'];
      final accountId = rawAccountId is int ? rawAccountId : null;
      return NotificationNavigationPayload(
        redirectUri: redirectUri,
        accountId: accountId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotificationNavigationPayload &&
            runtimeType == other.runtimeType &&
            redirectUri == other.redirectUri &&
            accountId == other.accountId;
  }

  @override
  int get hashCode => Object.hash(redirectUri, accountId);

  @override
  String toString() =>
      'NotificationNavigationPayload(redirectUri: $redirectUri, accountId: $accountId)';
}

/// Coordinates pending notification tap targets across cold and warm launches.
class NotificationNavigationCoordinator extends ChangeNotifier {
  static final NotificationNavigationCoordinator instance =
      NotificationNavigationCoordinator();

  NotificationNavigationCoordinator();

  NotificationNavigationPayload? _pending;
  NotificationNavigationPayload? _dispatched;

  NotificationNavigationPayload? get pending => _pending;
  NotificationNavigationPayload? get dispatched => _dispatched;

  /// Records a tapped notification response unless it was dismissed or null.
  bool handleNotificationResponse(NotificationResponse? response) {
    if (response == null ||
        response.notificationResponseType ==
            NotificationResponseType.notificationDismissed) {
      return false;
    }
    return handlePayload(response.payload);
  }

  /// Parses and stores [rawPayload] as the pending navigation target.
  bool handlePayload(String? rawPayload) {
    final parsed = NotificationNavigationPayload.tryParse(rawPayload);
    if (parsed == null) {
      if (rawPayload != null && rawPayload.trim().isNotEmpty) {
        logger.w('Ignoring invalid notification payload: $rawPayload');
      }
      return false;
    }
    _pending = parsed;
    _dispatched = null;
    notifyListeners();
    return true;
  }

  /// Returns the pending payload without consuming it if it matches
  /// [activeAccountId].
  ///
  /// When [activeAccountId] is non-null and differs from the payload's
  /// `accountId`, returns `null` so an account switch can run first.
  NotificationNavigationPayload? peekPending({int? activeAccountId}) {
    final current = _pending;
    if (current == null) return null;
    if (current.accountId != null &&
        activeAccountId != null &&
        current.accountId != activeAccountId) {
      return null;
    }
    return current;
  }

  /// Marks [payload] as dispatched to the router while keeping it pending until
  /// the destination route commits.
  void markDispatched(NotificationNavigationPayload payload) {
    if (identical(_pending, payload)) {
      _dispatched = payload;
    }
  }

  /// Clears the pending payload once its dispatched route has committed.
  bool clearIfDispatched() {
    if (_pending != null && identical(_pending, _dispatched)) {
      _pending = null;
      _dispatched = null;
      return true;
    }
    return false;
  }

  /// Consumes and returns the pending payload if it matches [activeAccountId].
  ///
  /// When [activeAccountId] is non-null and differs from the payload's
  /// `accountId`, the payload is retained so an account switch can run first.
  NotificationNavigationPayload? takePending({int? activeAccountId}) {
    final current = peekPending(activeAccountId: activeAccountId);
    if (current == null) return null;
    _pending = null;
    _dispatched = null;
    return current;
  }

  void clearPending() {
    _pending = null;
    _dispatched = null;
  }

  @visibleForTesting
  void reset() {
    _pending = null;
    _dispatched = null;
  }
}

/// Returns the pending notification's account id if that account still exists;
/// clears the pending target otherwise.
int? resolvePendingNotificationAccountId(
  NotificationNavigationCoordinator coordinator,
  List<AccountSummary> accounts,
) {
  final pendingAccountId = coordinator.pending?.accountId;
  if (pendingAccountId == null) return null;
  if (accounts.any((a) => a.localId == pendingAccountId)) {
    return pendingAccountId;
  }
  coordinator.clearPending();
  return null;
}

final notificationNavigationProvider =
    Provider<NotificationNavigationCoordinator>(
      (ref) => NotificationNavigationCoordinator.instance,
    );

/// Drives `go_router` navigation and account switching when notifications are tapped.
class NotificationNavigationDriver {
  final Ref _ref;
  late final NotificationNavigationCoordinator _coordinator;
  late final _router = _ref.read(goRouterProvider);
  bool _disposed = false;
  bool _scheduled = false;
  bool _processing = false;
  bool _rerunRequested = false;
  bool _commitClearScheduled = false;
  Timer? _commitClearTimer;
  NotificationNavigationPayload? _attemptedSwitchPayload;

  NotificationNavigationDriver(this._ref) {
    _coordinator = _ref.read(notificationNavigationProvider);
    _coordinator.addListener(_scheduleProcess);
    _router.routerDelegate.addListener(_onRouteCommitted);
    _ref.onDispose(() {
      _disposed = true;
      _commitClearTimer?.cancel();
      _commitClearTimer = null;
      _coordinator.removeListener(_scheduleProcess);
      _router.routerDelegate.removeListener(_onRouteCommitted);
    });

    _ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.phase == AuthPhase.unauthenticated) {
        _coordinator.clearPending();
        _attemptedSwitchPayload = null;
      } else if (next.phase == AuthPhase.authenticated) {
        _scheduleProcess();
      }
    });

    if (_coordinator.pending != null) {
      _scheduleProcess();
    }
  }

  static bool _isAuthGatePath(String path) =>
      path.isEmpty ||
      path == '/startup' ||
      path == '/privacy-policy' ||
      path == '/welcome';

  bool _hasCommittedLocation([String? expectedUri]) {
    final delegateUri = _router.routerDelegate.currentConfiguration.uri;
    final infoUri = _router.routeInformationProvider.value.uri;
    if (_isAuthGatePath(delegateUri.path) || _isAuthGatePath(infoUri.path)) {
      return false;
    }
    if (expectedUri != null) {
      return delegateUri.toString() == expectedUri &&
          infoUri.toString() == expectedUri;
    }
    return true;
  }

  void _scheduleCommitClear() {
    if (_disposed || _commitClearScheduled) return;
    _commitClearScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _commitClearScheduled = false;
      if (_disposed) return;
      // Wait for Router's post-frame _reportRouteInformation to update
      // routeInformationProvider.value before clearing the pending target.
      _commitClearTimer?.cancel();
      _commitClearTimer = Timer(Duration.zero, () {
        _commitClearTimer = null;
        _onRouteCommitted();
      });
    });
  }

  void _onRouteCommitted() {
    if (_disposed || _coordinator.pending == null) return;
    final auth = _ref.read(authControllerProvider);
    if (auth.phase != AuthPhase.authenticated) return;
    if (!_hasCommittedLocation()) {
      final delegatePath = _router.routerDelegate.currentConfiguration.uri.path;
      if (!_isAuthGatePath(delegatePath)) {
        _scheduleCommitClear();
      }
      return;
    }
    _coordinator.clearIfDispatched();
  }

  void _scheduleProcess() {
    if (_disposed) return;
    if (_processing) {
      _rerunRequested = true;
      return;
    }
    if (_scheduled) return;
    _scheduled = true;

    void run() {
      _scheduled = false;
      if (!_disposed) {
        unawaited(_process());
      }
    }

    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
      WidgetsBinding.instance.ensureVisualUpdate();
    } else {
      scheduleMicrotask(run);
    }
  }

  Future<void> _process() async {
    if (_disposed) return;
    if (_processing) {
      _rerunRequested = true;
      return;
    }
    _processing = true;
    try {
      do {
        _rerunRequested = false;
        while (!_disposed) {
          final pending = _coordinator.pending;
          if (pending == null) break;

          final auth = _ref.read(authControllerProvider);
          if (auth.phase == AuthPhase.unauthenticated) {
            _coordinator.clearPending();
            _attemptedSwitchPayload = null;
            break;
          }
          if (auth.phase != AuthPhase.authenticated) {
            break;
          }

          final shared = _ref.read(sharedOverAccountSettingsProvider);
          if (!isPrivacyPolicyAccepted(shared)) {
            break;
          }

          final activeAccountId = _ref.read(activeAccountProvider)?.localId;
          if (pending.accountId == null ||
              pending.accountId == activeAccountId) {
            if (_hasCommittedLocation(pending.redirectUri)) {
              _attemptedSwitchPayload = null;
              _coordinator.clearPending();
              continue;
            }
            if (identical(_coordinator.dispatched, pending)) {
              break;
            }
            _coordinator.markDispatched(pending);
            _attemptedSwitchPayload = null;
            _router.go(pending.redirectUri);
            break;
          }

          if (identical(_attemptedSwitchPayload, pending)) {
            _coordinator.clearPending();
            _attemptedSwitchPayload = null;
            break;
          }
          _attemptedSwitchPayload = pending;

          final accounts = await _ref.read(accountsProvider.future);
          if (_disposed) return;
          if (!identical(_coordinator.pending, pending)) {
            continue;
          }
          if (!accounts.any((a) => a.localId == pending.accountId)) {
            logger.w(
              'Ignoring notification for missing account ${pending.accountId}',
            );
            _coordinator.clearPending();
            _attemptedSwitchPayload = null;
            break;
          }

          final result = await _ref
              .read(authControllerProvider.notifier)
              .loginWithAccountResult(pending.accountId!);
          if (_disposed) return;
          if (!result.succeeded) {
            if (identical(_coordinator.pending, pending)) {
              _coordinator.clearPending();
            }
            _attemptedSwitchPayload = null;
            break;
          }
        }
      } while (_rerunRequested && !_disposed);
    } finally {
      _processing = false;
    }
  }
}

final notificationNavigationDriverProvider =
    Provider<NotificationNavigationDriver>(
      (ref) => NotificationNavigationDriver(ref),
    );
