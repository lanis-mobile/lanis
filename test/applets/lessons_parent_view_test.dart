import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/applets/lessons/routes.dart';
import 'package:lanis/applets/lessons/parent/lessons_parent_view.dart';
import 'package:lanis/utils/deep_link.dart';
import '../helpers/test_app.dart';

class _Context implements AppletContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements LanisSession {
  @override
  AccountType get accountTypeOrNull => AccountType.parent;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadySession extends Session {
  @override
  LanisSession build() => _Session();
}

CurrentEntry entry() => CurrentEntry(
  entryID: 'entry',
  topicTitle: 'Read-only topic',
  topicDate: DateTime(2026, 11, 17),
  files: [],
  uploads: [
    LessonUpload(
      name: 'Student submission',
      status: 'open',
      url: Uri.parse('meinunterricht.php?a=upload'),
    ),
  ],
  homework: Homework(description: 'Read a chapter', homeWorkDone: false),
);

class _Parser extends LessonsParentParser {
  final List<String> urls = [];
  int overviewCalls = 0;
  int pupilCount;
  bool emitLoading = false;
  bool offline;
  _Parser({this.pupilCount = 2, this.offline = false})
    : super(_Context(), isConnected: () async => true);
  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    if (offline) {
      addResponse(
        FetcherResponse(
          status: FetcherStatus.error,
          contentStatus: ContentStatus.offline,
          error: ExceptionWithStackTrace(
            exception: NoConnectionException(),
            stackTrace: StackTrace.empty,
          ),
        ),
      );
      return;
    }
    if (emitLoading) {
      addResponse(FetcherResponse(status: FetcherStatus.fetching, error: null));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    addResponse(
      FetcherResponse(
        status: FetcherStatus.done,
        error: null,
        content: await getHome(),
      ),
    );
  }

  @override
  Future<ParentLessonsOverview> getHome() async {
    overviewCalls++;
    return ParentLessonsOverview(
      lessonsByPupil: {
        for (final id in [for (var i = 1; i <= pupilCount; i++) '$i'])
          LessonPupil(id: id, name: 'Child $id'): [
            Lesson(
              courseID: '20',
              name: 'Course child $id',
              pupilId: id,
              teachers: [],
              attendances: {'fehlend': id},
              currentEntry: entry(),
              courseURL: Uri.parse(
                'meinunterricht.php?a=sus_view&id=20&p=$id&halb=1&extra=keep',
              ),
            ),
          ],
      },
    );
  }

  @override
  Future<DetailedLesson> getDetailedCourseView(
    String url, {
    bool force = false,
  }) async {
    urls.add(url);
    return DetailedLesson(
      courseID: '20',
      pupilId: Uri.parse(url).queryParameters['p'],
      name: 'Course',
      teachers: [],
      history: [entry()],
      marks: [],
      exams: [],
      attendances: {},
      semester1URL: Uri.parse('meinunterricht.php?a=sus_view&id=20&halb=1'),
    );
  }
}

void main() {
  tearDown(LanisClient.reset);
  Future<_Parser> pump(
    WidgetTester tester, {
    String location = '/parent/lessons/home',
    int pupilCount = 2,
    bool offline = false,
    Function? openDrawerCb,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final parser = _Parser(pupilCount: pupilCount, offline: offline);
    addTearDown(parser.dispose);
    await pumpTestRouterApp(
      tester,
      initialLocation: location,
      routes: buildLessonsRoutes(
        AppletRouteContext(
          rootNavigatorKey: GlobalKey<NavigatorState>(),
          homeBody: (_) => LessonsParentView(openDrawerCb: openDrawerCb),
        ),
      ),
      overrides: [
        sessionProvider.overrideWith(_ReadySession.new),
        lessonsParentParserProvider.overrideWithValue(parser),
        lessonsStudentParserProvider.overrideWith(
          (ref) => throw StateError('Parent view used student parser'),
        ),
      ],
    );
    await tester.pumpAndSettle();
    return parser;
  }

  testWidgets(
    'parent Lessons keeps its title and drawer on offline error and retry',
    (tester) async {
      var opened = 0;
      final parser = await pump(
        tester,
        offline: true,
        openDrawerCb: () => opened++,
      );
      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Lessons'),
        ),
        findsOneWidget,
      );
      expect(find.text('No internet connection!'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      expect(opened, 1);
      parser.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Child 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('parent attendance error retains its own app bar', (
    tester,
  ) async {
    await pump(
      tester,
      location: '/parent/lessons/attendances?pupil=1',
      offline: true,
    );
    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Attendances'),
      ),
      findsOneWidget,
    );
    expect(find.text('No internet connection!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'single child uses an appbar subtitle and gains tabs after refresh',
    (tester) async {
      final parser = await pump(tester, pupilCount: 1);
      expect(find.byType(TabBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Child 1'),
        ),
        findsOneWidget,
      );
      parser.pupilCount = 2;
      await parser.fetchData(forceRefresh: true);
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Child 1'), findsOneWidget);
      parser.pupilCount = 1;
      await parser.fetchData(forceRefresh: true);
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Child 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'parent module groups children and opens the exact course read-only',
    (tester) async {
      expect(
        lessonsDefinition.supportedAccountTypes,
        contains(AccountType.parent),
      );
      final parser = await pump(tester);
      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(parser.overviewCalls, 1);
      expect(find.byType(Checkbox), findsNothing);
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
      expect(find.byType(ExpansionTile), findsNothing);
      await tester.tap(find.text('Child 2'));
      await tester.pumpAndSettle();
      expect(parser.overviewCalls, 1);
      await tester.tap(find.text('Course child 2'));
      await tester.pumpAndSettle();
      expect(parser.urls, [
        'meinunterricht.php?a=sus_view&id=20&p=2&halb=1&extra=keep',
      ]);
      expect(find.text('Read-only topic'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Child 2'),
        ),
        findsOneWidget,
      );
      expect(find.text('Student submission'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(find.byIcon(Icons.looks_one_outlined));
      await tester.pumpAndSettle();
      expect(Uri.parse(parser.urls.last).queryParameters['p'], '2');
      expect(Uri.parse(parser.urls.last).queryParameters['halb'], '1');
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Child 2'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('parent attendance totals include only the selected child', (
    tester,
  ) async {
    await pump(tester, location: '/parent/lessons/attendances?pupil=2');
    expect(find.text('Course child 2'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Child 2')),
      findsOneWidget,
    );
    expect(find.text('Course child 1'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('attendance FAB follows the selected child tab', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Child 2'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Course child 2'), findsOneWidget);
    expect(find.text('Course child 1'), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Child 2')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'overflowing pupil tabs scroll and keep selection after refresh',
    (tester) async {
      final parser = await pump(tester, pupilCount: 24);
      await tester.ensureVisible(find.text('Child 24'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Child 24'));
      await tester.pumpAndSettle();
      expect(find.text('Course child 24'), findsOneWidget);
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 23);
      parser.pupilCount = 25;
      await parser.fetchData(forceRefresh: true);
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 23);
      parser.emitLoading = true;
      final refreshing = parser.fetchData(forceRefresh: true);
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Lessons'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await refreshing;
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 23);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'course deep links resolve the child subtitle without a name parameter',
    (tester) async {
      final parser = await pump(
        tester,
        location: Uri(
          path: '/parent/lessons/course/20',
          queryParameters: {'url': 'meinunterricht.php?a=sus_view&id=20&p=2'},
        ).toString(),
      );
      expect(parser.overviewCalls, 1);
      expect(parser.urls, ['meinunterricht.php?a=sus_view&id=20&p=2']);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Child 2'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'parent course links without a pupil are rejected before fetching',
    (tester) async {
      final parser = await pump(
        tester,
        location: Uri(
          path: '/parent/lessons/course/20',
          queryParameters: {'url': 'meinunterricht.php?a=sus_view&id=20'},
        ).toString(),
      );
      expect(find.byType(DeepLinkErrorPage), findsOneWidget);
      expect(parser.urls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
