import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// GlitchTip (Sentry-compatible) endpoint for error events only.
const glitchtipDsn =
    'https://d89e10f531084447ace3f71f0861e357@glitchtip.orion.alessioc42.dev/1';

/// Configure [SentryFlutter] for our self-hosted GlitchTip instance.
///
/// Error reporting only — no traces, metrics, profiles, logs, or session
/// replay. [sendDefaultPii] is enabled for richer self-hosted debug context.
void configureGlitchTip(SentryFlutterOptions options) {
  options.dsn = glitchtipDsn;
  options.sendDefaultPii = true;
  options.environment = kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';

  // Error events only.
  options.tracesSampleRate = 0;
  options.enableAutoPerformanceTracing = false;
  options.enableUserInteractionTracing = false;
  options.enableFramesTracking = false;
  options.enableLogs = false;
  options.replay.sessionSampleRate = 0;
  options.replay.onErrorSampleRate = 0;
}

/// Initialize GlitchTip and run [appRunner] under Sentry's error handlers.
Future<void> initGlitchTip(FutureOr<void> Function() appRunner) {
  return SentryFlutter.init(
    configureGlitchTip,
    appRunner: appRunner,
  );
}
