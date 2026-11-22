import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/view/settings/subsettings/debug_export.dart';
import 'package:lanis/view/settings/subsettings/debug_export_presets.dart';

class _RedirectAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.uri.host == 'start.schulportal.hessen.de') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['https://cdn.example.invalid/asset'],
          'set-cookie': ['SPH-Session=secret-token; HttpOnly'],
          'x-custom-response': ['keep-me'],
        },
      );
    }
    return ResponseBody.fromString(
      'ok',
      200,
      headers: {
        'Set-Cookie': ['sid=another-secret'],
        'x-other': ['visible'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('debug_export header redaction and redirect handling', () {
    test('redactDebugExportHeaders redacts auth/cookie headers case-insensitively', () {
      final redacted = redactDebugExportHeaders({
        'Cookie': 'sid=123',
        'Set-Cookie': 'sid=456',
        'Authorization': 'Bearer abc',
        'Proxy-Authorization': 'Basic xyz',
        'X-Requested-With': 'XMLHttpRequest',
      });
      expect(redacted['Cookie'], '<redacted>');
      expect(redacted['Set-Cookie'], '<redacted>');
      expect(redacted['Authorization'], '<redacted>');
      expect(redacted['Proxy-Authorization'], '<redacted>');
      expect(redacted['X-Requested-With'], 'XMLHttpRequest');
    });

    test('stripSensitiveCrossHostHeaders drops only auth/cookie headers across hosts and keeps custom headers', () {
      final headers = {
        'Cookie': 'sid=123',
        'Authorization': 'Bearer abc',
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json',
      };

      final sameHost = stripSensitiveCrossHostHeaders(
        headers,
        fromUrl: 'https://start.schulportal.hessen.de/a',
        toUrl: 'https://start.schulportal.hessen.de/b',
      );
      expect(sameHost, headers);

      final crossHost = stripSensitiveCrossHostHeaders(
        headers,
        fromUrl: 'https://start.schulportal.hessen.de/a',
        toUrl: 'https://other.example.invalid/b',
      );
      expect(crossHost, {
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json',
      });
    });

    test('appendRequestSection redacts Set-Cookie in output and keeps custom headers on redirect', () async {
      final adapter = _RedirectAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);

      final report = MemoryLogger();
      await appendRequestSection(
        report: report,
        sectionName: 'test',
        dio: dio,
        request: const DebugExportHttpRequest(
          method: 'GET',
          url: 'https://start.schulportal.hessen.de/start.php',
          headers: {
            'Cookie': 'sid=req-secret',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      final output = report.logs.toString();
      expect(output, isNot(contains('secret-token')));
      expect(output, isNot(contains('another-secret')));
      expect(output, isNot(contains('req-secret')));
      expect(output, contains('<redacted>'));
      expect(output, contains('keep-me'));
      expect(output, contains('visible'));

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.headers['Cookie'], isNull);
      expect(adapter.requests.last.headers['X-Requested-With'], 'XMLHttpRequest');
    });
  });
}
