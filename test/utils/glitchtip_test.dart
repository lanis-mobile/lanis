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
    expect(options.beforeSendLog, isNotNull);
    expect(options.beforeSendMetric, isNotNull);
    expect(options.replay.sessionSampleRate, 0);
    expect(options.replay.onErrorSampleRate, 0);
    expect(options.beforeSend, isNotNull);
  });

  test('logs and metrics are dropped even when reporting is enabled', () async {
    final options = SentryFlutterOptions(dsn: glitchtipDsn);
    configureGlitchTip(options);
    setGlitchTipReportingEnabled(true);
    final traceId = SentryId.newId();
    final log = SentryLog(
      timestamp: DateTime.now(),
      traceId: traceId,
      level: SentryLogLevel.info,
      body: 'private content',
      attributes: {},
    );
    final metric = SentryCounterMetric(
      timestamp: DateTime.now(),
      traceId: traceId,
      name: 'test',
      value: 1,
    );
    expect(await options.beforeSendLog!(log, Hint()), isNull);
    expect(await options.beforeSendMetric!(metric, Hint()), isNull);
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

  test('sanitizeGlitchTipLocation strips PII query params and keeps allowlist', () {
    expect(
      sanitizeGlitchTipLocation(
        Uri.parse(
          '/conversations/create?subject=Secret&receivers=alice&type=group',
        ),
      ),
      '/conversations/create?type=group',
    );
    expect(
      sanitizeGlitchTipLocation(
        Uri.parse(
          '/lessons/course/42?title=Math&pupilName=Max&tab=homework&status=open',
        ),
      ),
      '/lessons/course/42?tab=homework&status=open',
    );
    expect(
      sanitizeGlitchTipLocation(
        Uri.parse('/lessons/parent?pupil=101&topic=Private'),
      ),
      '/lessons/parent',
    );
    expect(sanitizeGlitchTipLocation(Uri.parse('')), '/');
  });
}
