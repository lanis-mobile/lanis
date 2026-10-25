import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/view/settings/subsettings/about.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

class _OnlineChecker extends ConnectionChecker {
  @override
  Future<bool> testConnection() async => true;
}

class _ReadySession extends Session {
  final LanisSession session;
  _ReadySession(this.session);

  @override
  LanisSession build() => session;
}

void main() {
  tearDown(LanisClient.reset);

  for (final fail in [false, true]) {
    testWidgets(
      'contributors ${fail ? 'error' : 'success'} after disposal is harmless',
      (tester) async {
        final response = Completer<void>();
        final started = Completer<void>();
        final session = LanisSession(
          account: ClearTextAccount(
            localId: 1,
            schoolID: 1,
            username: 'test',
            password: 'test',
            schoolName: 'Test',
          ),
          config: const LanisConfig(),
          connectionChecker: _OnlineChecker(),
        );
        addTearDown(() async {
          await session.dispose();
          session.connectionChecker.dispose();
        });
        session.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              started.complete();
              await response.future;
              if (fail) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    error: 'request failed',
                  ),
                );
              } else {
                handler.resolve(
                  Response(requestOptions: options, data: const []),
                );
              }
            },
          ),
        );

        await pumpTestApp(
          tester,
          child: Consumer(
            builder: (context, ref, _) =>
                ref.watch(sessionProvider).asData?.value == null
                ? const SizedBox.shrink()
                : const AboutSettings(),
          ),
          overrides: [
            sessionProvider.overrideWith(() => _ReadySession(session)),
          ],
        );
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.byType(AboutSettings), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(started.isCompleted, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());

        await tester.runAsync(() async {
          response.complete();
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
