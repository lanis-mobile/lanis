import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:liblanis/liblanis.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// GlitchTip (Sentry-compatible) endpoint for error events only.
const glitchtipDsn =
    'https://d89e10f531084447ace3f71f0861e357@glitchtip.orion.alessioc42.dev/1';

/// [shared_settings] key for device-wide GlitchTip opt-in (default off).
const glitchTipEnabledKey = 'glitchtip-enabled';

/// Runtime gate for outbound error events. Default off until synced from settings.
bool glitchTipReportingEnabled = false;

bool isGlitchTipEnabled(TypedSettings shared) {
  return shared.getBool(glitchTipEnabledKey) ?? false;
}

void setGlitchTipEnabled(TypedSettings shared, bool enabled) {
  shared.setBool(glitchTipEnabledKey, enabled);
  setGlitchTipReportingEnabled(enabled);
}

void setGlitchTipReportingEnabled(bool enabled) {
  glitchTipReportingEnabled = enabled;
}

/// Capture an exception only when the user has opted into GlitchTip.
Future<void> captureGlitchTipException(
  Object throwable, {
  StackTrace? stackTrace,
}) async {
  if (!glitchTipReportingEnabled) return;
  await Sentry.captureException(throwable, stackTrace: stackTrace);
}

/// Report an unexpected applet fetch error from liblanis (opt-in gated).
Future<void> captureUnexpectedAppletError(
  Object throwable,
  StackTrace stackTrace, {
  required String appletPhpUrl,
}) async {
  if (!glitchTipReportingEnabled) return;
  await Sentry.addBreadcrumb(
    Breadcrumb(
      category: 'applet',
      message: 'Unexpected fetch error',
      data: {'appletPhpUrl': appletPhpUrl},
      level: SentryLevel.error,
    ),
  );
  await Sentry.captureException(throwable, stackTrace: stackTrace);
}

/// Configure [SentryFlutter] for our self-hosted GlitchTip instance.
///
/// Error reporting only — no session envelopes, traces, metrics, profiles,
/// logs, or session replay. [sendDefaultPii] stays off to avoid IP, device
/// name, and UI text labels on events. Outbound events are dropped until
/// [glitchTipReportingEnabled] is true.
void configureGlitchTip(SentryFlutterOptions options) {
  options.dsn = glitchtipDsn;
  options.sendDefaultPii = false;
  options.environment = kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';

  // Error events only.
  options.enableAutoSessionTracking = false;
  options.tracesSampleRate = 0;
  options.enableAutoPerformanceTracing = false;
  options.enableUserInteractionTracing = false;
  options.enableFramesTracking = false;
  options.enableLogs = false;
  options.replay.sessionSampleRate = 0;
  options.replay.onErrorSampleRate = 0;

  options.beforeSend = (event, hint) {
    if (!glitchTipReportingEnabled) return null;
    return event;
  };
}

/// Initialize GlitchTip and run [appRunner] under Sentry's error handlers.
Future<void> initGlitchTip(FutureOr<void> Function() appRunner) {
  return SentryFlutter.init(
    configureGlitchTip,
    appRunner: appRunner,
  );
}

/// Load the shared opt-in flag from the configured Lanis database.
void syncGlitchTipReportingFromConfig() {
  final config = LanisClient.config;
  if (config == null) {
    setGlitchTipReportingEnabled(false);
    return;
  }
  final db = LanisDatabase.open(
    path: config.databasePath,
    secretStore: config.secretStore,
  );
  try {
    setGlitchTipReportingEnabled(isGlitchTipEnabled(TypedSettings.shared(db)));
  } finally {
    db.dispose();
  }
}
