import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:lanis/utils/glitchtip.dart';

void main() {
  test('configureGlitchTip disables PII session traces and replay', () {
    final options = SentryFlutterOptions(dsn: glitchtipDsn);
    configureGlitchTip(options);

    expect(options.dsn, glitchtipDsn);
    expect(options.sendDefaultPii, isFalse);
    expect(options.enableAutoSessionTracking, isFalse);
    expect(options.tracesSampleRate, 0);
    expect(options.enableAutoPerformanceTracing, isFalse);
    expect(options.enableUserInteractionTracing, isFalse);
    expect(options.enableFramesTracking, isFalse);
    expect(options.enableLogs, isFalse);
    expect(options.replay.sessionSampleRate, 0);
    expect(options.replay.onErrorSampleRate, 0);
  });
}
