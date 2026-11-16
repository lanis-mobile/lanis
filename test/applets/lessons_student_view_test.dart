import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/lessons/student/lessons_student_view.dart';
import 'package:liblanis/liblanis.dart';
import '../helpers/test_app.dart';

class _Context implements AppletContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements LanisSession {
  @override
  AccountType get accountTypeOrNull => AccountType.student;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadySession extends Session {
  @override
  LanisSession build() => _Session();
}

class _Parser extends LessonsStudentParser {
  final Lessons lessons;
  _Parser(this.lessons) : super(_Context(), isConnected: () async => true);
  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    addResponse(
      FetcherResponse(
        status: FetcherStatus.done,
        content: lessons,
        error: null,
      ),
    );
  }
}

Lesson course({required bool older}) => Lesson(
  courseID: '20',
  name: older ? 'Older informatics' : 'Current informatics',
  teachers: [],
  courseURL: Uri.parse(
    'meinunterricht.php?a=sus_view&id=20${older ? '&halb=1' : ''}',
  ),
  isOlder: older,
);
void main() {
  tearDown(LanisClient.reset);
  testWidgets(
    'older courses appear below current courses and open their semester',
    (tester) async {
      final parser = _Parser([course(older: true), course(older: false)]);
      addTearDown(parser.dispose);
      await pumpTestRouterApp(
        tester,
        initialLocation: '/student/lessons/home',
        routes: [
          GoRoute(
            path: '/student/lessons/home',
            builder: (_, _) => const LessonsStudentView(),
          ),
          GoRoute(
            path: '/student/lessons/course/:id',
            builder: (_, state) => Scaffold(
              body: Text(
                'Opened ${state.pathParameters['id']} semester ${state.uri.queryParameters['semester']}',
              ),
            ),
          ),
        ],
        overrides: [
          sessionProvider.overrideWith(_ReadySession.new),
          lessonsStudentParserProvider.overrideWithValue(parser),
        ],
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Current informatics')).dy,
        lessThan(tester.getTopLeft(find.text('Older courses')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Older courses')).dy,
        lessThan(tester.getTopLeft(find.text('Older informatics')).dy),
      );
      await tester.tap(find.text('Older informatics'));
      await tester.pumpAndSettle();
      expect(find.text('Opened 20 semester 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final older in [false, true]) {
    testWidgets(
      'overview works with ${older ? 'only older' : 'only current'} courses',
      (tester) async {
        final parser = _Parser([course(older: older)]);
        addTearDown(parser.dispose);
        await pumpTestApp(
          tester,
          child: const LessonsStudentView(),
          overrides: [
            sessionProvider.overrideWith(_ReadySession.new),
            lessonsStudentParserProvider.overrideWithValue(parser),
          ],
        );
        await tester.pumpAndSettle();
        expect(
          find.text(older ? 'Older informatics' : 'Current informatics'),
          findsOneWidget,
        );
        expect(
          find.text('Older courses'),
          older ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
