import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/view/settings/subsettings/debug_export.dart';
import 'package:lanis/view/settings/subsettings/debug_export_presets.dart';

class _MapAdapter implements HttpClientAdapter {
  final Map<String, String> responses;
  final requestedUrls = <String>[];

  _MapAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requestedUrls.add(url);
    final body = responses[url];
    if (body == null) {
      return ResponseBody.fromString('not found: $url', 404);
    }
    return ResponseBody.fromString(body, 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('debug export HTML link extractors', () {
    test('parseParentTimetableUrls extracts unique same-origin child detail URLs', () {
      const html = '''
<html><body>
  <div id="content">
    <div id="accordion">
      <a class="list-group-item" href="stundenplan.php?a=detail_klasse&amp;p=101">Alice (5a)</a>
      <a class="list-group-item" href="stundenplan.php?a=detail_klasse&amp;p=101#top">Alice dup</a>
      <a class="list-group-item" href="/stundenplan.php?a=detail_klasse&amp;p=102">Bob (7b)</a>
      <a class="list-group-item" href="https://evil.example/stundenplan.php?a=detail_klasse&amp;p=999">Evil</a>
      <a class="list-group-item" href="stundenplan.php?a=other&amp;p=103">Other</a>
    </div>
  </div>
</body></html>
''';
      final urls = parseParentTimetableUrls(html);
      expect(urls.map((u) => u.toString()).toList(), [
        'https://start.schulportal.hessen.de/stundenplan.php?a=detail_klasse&p=101',
        'https://start.schulportal.hessen.de/stundenplan.php?a=detail_klasse&p=102',
      ]);
    });

    test('parseLessonsCourseUrls extracts student, older, and parent course URLs', () {
      const html = '''
<html><body>
  <div id="mappen">
    <a class="btn btn-primary" href="meinunterricht.php?a=sus_view&amp;id=10">Math</a>
    <a href="meinunterricht.php?a=sus_view&amp;id=10">Math dup</a>
    <a href="meinunterricht.php?a=sus_view&amp;id=10&amp;halb=1">Math old</a>
    <a href="meinunterricht.php?a=sus_view&amp;id=20&amp;p=101">Parent child course</a>
    <a href="meinunterricht.php?a=view&amp;id=30">Teacher course</a>
    <a href="https://evil.example/meinunterricht.php?a=sus_view&amp;id=99">Evil</a>
  </div>
</body></html>
''';
      final urls = parseLessonsCourseUrls(html);
      expect(urls.map((u) => u.toString()).toList(), [
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_view&id=10',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_view&id=10&halb=1',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_view&id=20&p=101',
      ]);
    });

    test('parseLessonsUploadUrls extracts 3rd-level sus_abgabe links', () {
      const html = '''
<html><body>
  <div id="history">
    <a href="meinunterricht.php?a=sus_abgabe&amp;id=1&amp;b=10&amp;e=5">Upload 1</a>
    <a href="meinunterricht.php?a=sus_abgabe&amp;id=1&amp;b=10&amp;e=5">Upload 1 dup</a>
    <a href="meinunterricht.php?a=sus_abgabe&amp;id=2&amp;b=10&amp;e=6&amp;p=101">Upload 2</a>
    <a href="meinunterricht.php?a=downloadFile&amp;id=10&amp;e=5&amp;f=a.pdf">Download</a>
  </div>
</body></html>
''';
      final urls = parseLessonsUploadUrls(html);
      expect(urls.map((u) => u.toString()).toList(), [
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_abgabe&id=1&b=10&e=5',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_abgabe&id=2&b=10&e=6&p=101',
      ]);
    });
  });

  group('appendDebugExportAppletSections', () {
    test('timetable fetches main page plus all discovered parent child timetables', () async {
      final adapter = _MapAdapter({
        'https://start.schulportal.hessen.de/stundenplan.php': '''
          <div id="content"><div id="accordion">
            <a class="list-group-item" href="stundenplan.php?a=detail_klasse&amp;p=101">Child 1</a>
            <a class="list-group-item" href="stundenplan.php?a=detail_klasse&amp;p=102">Child 2</a>
          </div></div>
        ''',
        'https://start.schulportal.hessen.de/stundenplan.php?a=detail_klasse&p=101':
            '<div id="all">plan-101</div>',
        'https://start.schulportal.hessen.de/stundenplan.php?a=detail_klasse&p=102':
            '<div id="all">plan-102</div>',
      });
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);

      final report = MemoryLogger();
      await appendDebugExportAppletSections(
        report: report,
        presetId: DebugExportPresetId.timetable,
        dio: dio,
      );

      expect(adapter.requestedUrls, [
        'https://start.schulportal.hessen.de/stundenplan.php',
        'https://start.schulportal.hessen.de/stundenplan.php?a=detail_klasse&p=101',
        'https://start.schulportal.hessen.de/stundenplan.php?a=detail_klasse&p=102',
      ]);
      final output = report.logs.toString();
      expect(output, contains('timetable/pupil#101'));
      expect(output, contains('plan-101'));
      expect(output, contains('timetable/pupil#102'));
      expect(output, contains('plan-102'));
    });

    test('lessons fetches overview, all 2nd-level courses, and all 3rd-level uploads without cap', () async {
      final adapter = _MapAdapter({
        'https://start.schulportal.hessen.de/meinunterricht.php': '''
          <a href="meinunterricht.php?a=sus_view&amp;id=10">Course 10</a>
          <a href="meinunterricht.php?a=sus_view&amp;id=20&amp;p=101">Course 20</a>
        ''',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_view&id=10':
            '''
          <div id="history">
            <a href="meinunterricht.php?a=sus_abgabe&amp;id=1&amp;b=10&amp;e=5">Upload 1</a>
            <a href="meinunterricht.php?a=sus_abgabe&amp;id=2&amp;b=10&amp;e=6">Upload 2</a>
          </div>
        ''',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_view&id=20&p=101':
            '''
          <div id="history">
            <a href="meinunterricht.php?a=sus_abgabe&amp;id=3&amp;b=20&amp;e=7&amp;p=101">Upload 3</a>
          </div>
        ''',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_abgabe&id=1&b=10&e=5':
            'upload-body-1',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_abgabe&id=2&b=10&e=6':
            'upload-body-2',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_abgabe&id=3&b=20&e=7&p=101':
            'upload-body-3',
      });
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);

      final report = MemoryLogger();
      await appendDebugExportAppletSections(
        report: report,
        presetId: DebugExportPresetId.lessons,
        dio: dio,
      );

      expect(adapter.requestedUrls, [
        'https://start.schulportal.hessen.de/meinunterricht.php',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_view&id=10',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_abgabe&id=1&b=10&e=5',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_abgabe&id=2&b=10&e=6',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_view&id=20&p=101',
        'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_abgabe&id=3&b=20&e=7&p=101',
      ]);
      final output = report.logs.toString();
      expect(output, contains('lessons/course#10'));
      expect(output, contains('lessons/upload#1_b=10_e=5'));
      expect(output, contains('upload-body-1'));
      expect(output, contains('upload-body-2'));
      expect(output, contains('lessons/course#20_p=101'));
      expect(output, contains('upload-body-3'));
    });

    test('debugExportPresets omits teacher lessons and exposes 7 applets', () {
      expect(debugExportPresets, hasLength(7));
      expect(
        debugExportPresets.map((p) => p.id).toList(),
        DebugExportPresetId.values,
      );
    });

    test('isDebugExportPresetAvailable enforces supported applets and account types', () {
      final lessons = debugExportPresets.firstWhere(
        (p) => p.id == DebugExportPresetId.lessons,
      );
      final studyGroups = debugExportPresets.firstWhere(
        (p) => p.id == DebugExportPresetId.studyGroups,
      );
      final supportedAll = {
        Applets.lessons.appletPhpUrl,
        Applets.studyGroups.appletPhpUrl,
      };

      expect(
        isDebugExportPresetAvailable(
          lessons,
          supportedAppletPhpUrls: supportedAll,
          accountType: AccountType.student,
        ),
        isTrue,
      );
      expect(
        isDebugExportPresetAvailable(
          lessons,
          supportedAppletPhpUrls: supportedAll,
          accountType: AccountType.parent,
        ),
        isTrue,
      );
      expect(
        isDebugExportPresetAvailable(
          lessons,
          supportedAppletPhpUrls: supportedAll,
          accountType: AccountType.teacher,
        ),
        isFalse,
      );
      expect(
        isDebugExportPresetAvailable(
          studyGroups,
          supportedAppletPhpUrls: supportedAll,
          accountType: AccountType.parent,
        ),
        isFalse,
      );
      expect(
        isDebugExportPresetAvailable(
          lessons,
          supportedAppletPhpUrls: const {},
          accountType: AccountType.student,
        ),
        isFalse,
      );
    });
  });
}
