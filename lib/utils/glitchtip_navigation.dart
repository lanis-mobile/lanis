import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Keeps GlitchTip/Sentry error context aligned with GoRouter's real location.
///
/// [SentryNavigatorObserver] alone often records an empty `to` on GoRouter
/// redirects into [StatefulShellRoute], so events stay stuck on `/startup`.
/// Listening to the router fixes the transaction name and adds a complete
/// navigation breadcrumb for the next error event.
VoidCallback attachGlitchTipRouteTracking(GoRouter router) {
  String? lastLocation;

  void sync() {
    final location = currentGoRouterLocation(router);
    if (location == null || location == lastLocation) return;

    final from = lastLocation;
    lastLocation = location;

    Sentry.addBreadcrumb(
      Breadcrumb(
        type: 'navigation',
        category: 'navigation',
        data: {
          if (from != null) 'from': from,
          'to': location,
          'state': 'go_router',
        },
      ),
    );

    Sentry.configureScope((scope) {
      scope.transaction = location;
      scope.setTag('route', location);
    });
  }

  sync();
  router.routerDelegate.addListener(sync);
  return () => router.routerDelegate.removeListener(sync);
}

/// Full path (+ query) currently shown by [router], or null if unavailable.
String? currentGoRouterLocation(GoRouter router) {
  try {
    final uri = router.routerDelegate.currentConfiguration.uri;
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (uri.hasQuery) return '$path?${uri.query}';
    return path;
  } catch (_) {
    return null;
  }
}

/// Observer for breadcrumbs only — performance transactions stay off.
SentryNavigatorObserver glitchTipNavigatorObserver() {
  return SentryNavigatorObserver(
    enableAutoTransactions: false,
    setRouteNameAsTransaction: true,
  );
}
