import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:lanis/utils/glitchtip.dart';
import 'package:lanis/utils/glitchtip_navigation.dart';

void main() {
  tearDown(() {
    setGlitchTipReportingEnabled(false);
    LanisClient.reset();
  });

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
    expect(options.beforeSend, isNotNull);
  });

  test('beforeSend drops events when reporting disabled', () async {
    final options = SentryFlutterOptions(dsn: glitchtipDsn);
    configureGlitchTip(options);
    setGlitchTipReportingEnabled(false);

    final event = SentryEvent();
    final result = await options.beforeSend!(event, Hint());
    expect(result, isNull);
  });

  test('beforeSend allows events when reporting enabled', () async {
    final options = SentryFlutterOptions(dsn: glitchtipDsn);
    configureGlitchTip(options);
    setGlitchTipReportingEnabled(true);

    final event = SentryEvent();
    final result = await options.beforeSend!(event, Hint());
    expect(result, same(event));
  });

  test('shared helpers default off and round-trip', () {
    LanisClient.configure();
    final container = ProviderContainer(overrides: LanisClient.overrides);
    addTearDown(container.dispose);

    final shared = container.read(sharedOverAccountSettingsProvider);
    expect(isGlitchTipEnabled(shared), isFalse);

    setGlitchTipEnabled(shared, true);
    expect(isGlitchTipEnabled(shared), isTrue);
    expect(glitchTipReportingEnabled, isTrue);

    setGlitchTipEnabled(shared, false);
    expect(isGlitchTipEnabled(shared), isFalse);
    expect(glitchTipReportingEnabled, isFalse);
  });

  test('glitchTipNavigatorObserver stays breadcrumb-only', () {
    final observer = glitchTipNavigatorObserver();
    expect(observer, isA<SentryNavigatorObserver>());
  });
}
