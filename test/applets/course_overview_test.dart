import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/lessons/student/course_overview.dart';
import 'package:liblanis/liblanis.dart';
import '../helpers/test_app.dart';

class _Context implements AppletContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements LanisSession {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadySession extends Session {
  final LanisSession session = _Session();
  @override
  LanisSession build() => session;
  @override
  Future<LanisSession> authenticate({
    String? withLoginUrl,
    bool withoutData = false,
  }) async => session;
}

class _Parser extends LessonsStudentParser {
  final completer = Completer<DetailedLesson>();
  int calls = 0;
  _Parser() : super(_Context(), isConnected: () async => true);
  @override
  Future<DetailedLesson> getDetailedCourseView(
    String url, {
    bool force = false,
  }) {
    calls++;
    return completer.future;
  }
}

void main() {
  tearDown(LanisClient.reset);
  const page = CourseOverviewAnsicht(
    dataFetchURL: 'meinunterricht.php?a=sus_view&id=20',
    title: 'Fuzz course',
  );
  testWidgets(
    'LANIS-MOBILE-EN: failed course load never dereferences null data',
    (tester) async {
      final parser = _Parser();
      addTearDown(parser.dispose);
      await pumpTestApp(
        tester,
        child: page,
        overrides: [
          lessonsStudentParserProvider.overrideWithValue(parser),
          sessionProvider.overrideWith(_ReadySession.new),
        ],
      );
      parser.completer.completeError(
        UnknownException('Missing teacher dropdown'),
      );
      await tester.pumpAndSettle();
      expect(parser.calls, 2);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.looks_one_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('course load finishing after disposal does not call setState', (
    tester,
  ) async {
    final parser = _Parser();
    addTearDown(parser.dispose);
    await pumpTestApp(
      tester,
      child: page,
      overrides: [lessonsStudentParserProvider.overrideWithValue(parser)],
    );
    await tester.pumpWidget(const SizedBox.shrink());
    parser.completer.complete(
      DetailedLesson(
        courseID: '20',
        name: 'Fuzz course',
        teachers: [],
        history: [],
        marks: [],
        exams: [],
        attendances: {},
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
