import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/conversations/conversations_nav.dart';
import 'package:lanis/applets/conversations/routes.dart';
import 'package:lanis/applets/conversations/view/new_conversation_configurator.dart';
import 'package:lanis/applets/lessons/student/course_overview.dart';
import 'package:lanis/applets/lessons/student/lesson_list_tile.dart';
import 'package:lanis/applets/study_groups/student/student_course_view.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _Context implements AppletContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSession implements LanisSession {
  final bool supportsConversations;
  _FakeSession({this.supportsConversations = true});

  @override
  bool doesSupportFeature(
    AppletMeta applet, {
    AccountType? overrideAccountType,
  }) {
    if (applet == Applets.conversations) return supportsConversations;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadySession extends Session {
  final _FakeSession _session;
  _ReadySession({bool supportsConversations = true})
    : _session = _FakeSession(supportsConversations: supportsConversations);

  @override
  LanisSession build() => _session;

  @override
  Future<LanisSession> authenticate({
    String? withLoginUrl,
    bool withoutData = false,
  }) async => _session;
}

class _FakeConversationsParser extends ConversationsParser {
  bool? _cached;
  final Future<bool> Function()? onCanChooseType;
  int canChooseTypeCalls = 0;
  int searchTeacherCalls = 0;

  _FakeConversationsParser({bool? cachedCanChooseType, this.onCanChooseType})
    : _cached = cachedCanChooseType,
      super(_Context(), isConnected: () async => true);

  @override
  bool? get cachedCanChooseType => _cached;

  @override
  Future<bool> canChooseType() async {
    canChooseTypeCalls++;
    if (onCanChooseType != null) {
      final result = await onCanChooseType!();
      _cached = result;
      return result;
    }
    _cached = false;
    return false;
  }

  @override
  Future<List<ReceiverEntry>> searchTeacher(String query) async {
    searchTeacherCalls++;
    return const [];
  }
}

class _FakeLessonsStudentParser extends LessonsStudentParser {
  final DetailedLesson detailedLesson;

  _FakeLessonsStudentParser(this.detailedLesson)
    : super(_Context(), isConnected: () async => true);

  @override
  Future<DetailedLesson> getDetailedCourseView(
    String url, {
    bool force = false,
  }) async => detailedLesson;
}

class _FakeLessonsParentParser extends LessonsParentParser {
  final DetailedLesson detailedLesson;

  _FakeLessonsParentParser(this.detailedLesson)
    : super(_Context(), isConnected: () async => true);

  @override
  Future<DetailedLesson> getDetailedCourseView(
    String url, {
    bool force = false,
  }) async => detailedLesson;
}

void main() {
  tearDown(resetAuthTestSeams);

  group('NewConversationConfigurator prefilled receivers', () {
    testWidgets(
      'pre-populates receiver chip, loads canChooseType when null, and never calls searchTeacher',
      (tester) async {
        final parser = _FakeConversationsParser(
          cachedCanChooseType: null,
          onCanChooseType: () async => true,
        );
        addTearDown(parser.dispose);

        ChatCreationData? submitted;
        await pumpTestApp(
          tester,
          overrides: [conversationsParserProvider.overrideWithValue(parser)],
          child: NewConversationConfigurator(
            initialReceivers: [
              ReceiverEntry('l-105044', 'Müller, Max (MÜL)', true),
            ],
            onSubmit: (data) => submitted = data,
          ),
        );
        await tester.pumpAndSettle();

        expect(parser.canChooseTypeCalls, 1);
        expect(parser.searchTeacherCalls, 0);
        expect(find.text('Müller, Max (MÜL)'), findsOneWidget);

        // Subject is empty initially, so Create should not submit yet.
        await tester.tap(find.text('Create'));
        await tester.pump();
        expect(submitted, isNull);

        // Enter subject and submit.
        await tester.enterText(
          find.byType(TextField).first,
          'Question about homework',
        );
        await tester.pump();

        await tester.tap(find.text('Create'));
        await tester.pump();

        expect(submitted, isNotNull);
        expect(submitted!.subject, 'Question about homework');
        expect(submitted!.receivers, ['l-105044']);
        expect(submitted!.type, isNotNull);
        expect(parser.searchTeacherCalls, 0);
      },
    );

    testWidgets(
      'handles canChooseType failure cleanly without crashing on cachedCanChooseType!',
      (tester) async {
        final parser = _FakeConversationsParser(
          cachedCanChooseType: null,
          onCanChooseType: () async => throw Exception('offline'),
        );
        addTearDown(parser.dispose);

        ChatCreationData? submitted;
        await pumpTestApp(
          tester,
          overrides: [conversationsParserProvider.overrideWithValue(parser)],
          child: NewConversationConfigurator(
            initialReceivers: [
              ReceiverEntry('l-316983', 'Caputo, Alessio (CAP)', true),
            ],
            initialSubject: 'Hello',
            onSubmit: (data) => submitted = data,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create'));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(submitted, isNotNull);
        expect(submitted!.subject, 'Hello');
        expect(submitted!.receivers, ['l-316983']);
        expect(submitted!.type, isNull);
      },
    );
  });

  group('Study Groups TeacherChip', () {
    Future<ConversationComposeExtra?> pumpChipWithRouter(
      WidgetTester tester, {
      required StudentStudyGroupTeacher teacher,
      bool supportsConversations = true,
    }) async {
      ConversationComposeExtra? capturedExtra;
      await pumpTestRouterApp(
        tester,
        initialLocation: '/study',
        overrides: [
          sessionProvider.overrideWith(
            () => _ReadySession(supportsConversations: supportsConversations),
          ),
        ],
        routes: [
          GoRoute(
            path: '/study',
            builder: (context, state) => Scaffold(
              body: Center(child: TeacherChip(teacher: teacher)),
            ),
          ),
          GoRoute(
            path: conversationsComposePath,
            builder: (context, state) {
              capturedExtra = state.extra as ConversationComposeExtra?;
              return const Scaffold(body: Text('Compose Destination'));
            },
          ),
        ],
      );
      await tester.pumpAndSettle();
      return capturedExtra;
    }

    testWidgets('conversationReceiverId only opens compose directly', (
      tester,
    ) async {
      ConversationComposeExtra? capturedExtra;
      await pumpTestRouterApp(
        tester,
        initialLocation: '/study',
        overrides: [
          sessionProvider.overrideWith(
            () => _ReadySession(supportsConversations: true),
          ),
        ],
        routes: [
          GoRoute(
            path: '/study',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TeacherChip(
                  teacher: StudentStudyGroupTeacher(
                    krz: 'WEB',
                    firstName: 'Anna',
                    lastName: 'Weber',
                    conversationReceiverId: 'l-200',
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: conversationsComposePath,
            builder: (context, state) {
              capturedExtra = state.extra as ConversationComposeExtra?;
              return const Scaffold(body: Text('Compose Destination'));
            },
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.email), findsNothing);

      await tester.tap(find.byType(TeacherChip));
      await tester.pumpAndSettle();

      expect(find.text('Compose Destination'), findsOneWidget);
      expect(capturedExtra, isNotNull);
      expect(capturedExtra!.initialReceivers.single.id, 'l-200');
      expect(
        capturedExtra!.initialReceivers.single.name,
        'Weber, Anna (WEB)',
      );
      expect(capturedExtra!.initialReceivers.single.isTeacher, isTrue);
    });

    testWidgets('both message and email opens bottom sheet to pick action', (
      tester,
    ) async {
      ConversationComposeExtra? capturedExtra;
      await pumpTestRouterApp(
        tester,
        initialLocation: '/study',
        overrides: [
          sessionProvider.overrideWith(
            () => _ReadySession(supportsConversations: true),
          ),
        ],
        routes: [
          GoRoute(
            path: '/study',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TeacherChip(
                  teacher: StudentStudyGroupTeacher(
                    krz: 'MUE',
                    firstName: 'Max',
                    lastName: 'Müller',
                    email: 'm.mueller@schule.hessen.de',
                    conversationReceiverId: 'l-100',
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: conversationsComposePath,
            builder: (context, state) {
              capturedExtra = state.extra as ConversationComposeExtra?;
              return const Scaffold(body: Text('Compose Destination'));
            },
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);

      await tester.tap(find.byType(TeacherChip));
      await tester.pumpAndSettle();

      // Sheet shows both Send message and Send email.
      expect(find.text('Send message'), findsOneWidget);
      expect(find.text('Send email'), findsOneWidget);
      expect(find.text('m.mueller@schule.hessen.de'), findsOneWidget);

      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();

      expect(find.text('Compose Destination'), findsOneWidget);
      expect(capturedExtra!.initialReceivers.single.id, 'l-100');
    });

    testWidgets('hides message icon when account does not support Conversations', (
      tester,
    ) async {
      await pumpChipWithRouter(
        tester,
        supportsConversations: false,
        teacher: StudentStudyGroupTeacher(
          krz: 'MUE',
          firstName: 'Max',
          lastName: 'Müller',
          email: 'm.mueller@schule.hessen.de',
          conversationReceiverId: 'l-100',
        ),
      );

      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('email only shows only email icon and neither shows no icons', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        overrides: [
          sessionProvider.overrideWith(
            () => _ReadySession(supportsConversations: true),
          ),
        ],
        child: Scaffold(
          body: Column(
            children: [
              TeacherChip(
                teacher: StudentStudyGroupTeacher(
                  krz: 'KLE',
                  firstName: 'Tom',
                  lastName: 'Klein',
                  email: 't.klein@schule.hessen.de',
                ),
              ),
              TeacherChip(
                teacher: StudentStudyGroupTeacher(
                  krz: 'BRA',
                  firstName: 'Lisa',
                  lastName: 'Braun',
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);

      // Tapping teacher with neither does nothing and throws no exception.
      await tester.tap(find.text('Braun, Lisa (BRA)'));
      await tester.pumpAndSettle();
      expect(find.text('Send message'), findsNothing);
      expect(find.text('Send email'), findsNothing);
    });
  });

  group('Lessons Overview LessonListTile long-press', () {
    testWidgets(
      'long-press always reveals bottom sheet even when only one action exists',
      (tester) async {
        ConversationComposeExtra? capturedExtra;
        final lesson = Lesson(
          courseID: '20',
          name: 'Mathematik LK',
          courseURL: Uri.parse('meinunterricht.php?a=sus_view&id=20'),
          teachers: [
            LessonTeacher(
              teacher: 'Müller, Max',
              teacherKuerzel: 'MUE',
              conversationReceiverId: 'l-105044',
            ),
          ],
        );

        await pumpTestRouterApp(
          tester,
          initialLocation: '/lessons',
          overrides: [
            sessionProvider.overrideWith(
              () => _ReadySession(supportsConversations: true),
            ),
          ],
          routes: [
            GoRoute(
              path: '/lessons',
              builder: (context, state) =>
                  Scaffold(body: LessonListTile(lesson: lesson)),
            ),
            GoRoute(
              path: conversationsComposePath,
              builder: (context, state) {
                capturedExtra = state.extra as ConversationComposeExtra?;
                return const Scaffold(body: Text('Compose Destination'));
              },
            ),
          ],
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.byType(LessonListTile));
        await tester.pumpAndSettle();

        // Must show bottom sheet instead of navigating directly.
        expect(find.text('Compose Destination'), findsNothing);
        expect(find.text('Send message'), findsOneWidget);
        expect(find.text('Mathematik LK'), findsNWidgets(2));
        expect(find.text('Müller, Max (MUE)'), findsOneWidget);

        await tester.tap(find.text('Send message'));
        await tester.pumpAndSettle();

        expect(find.text('Compose Destination'), findsOneWidget);
        expect(capturedExtra!.initialReceivers.single.id, 'l-105044');
        expect(capturedExtra!.initialReceivers.single.name, 'Müller, Max');
      },
    );
  });

  group('Lessons Course Detail (Student & Parent)', () {
    for (final accountType in [AccountType.student, AccountType.parent]) {
      testWidgets(
        'shows AppBar contact action and opens sheet with message & email for ${accountType.name}',
        (tester) async {
          final detailed = DetailedLesson(
            courseID: '20',
            pupilId: accountType == AccountType.parent ? '101' : null,
            name: 'Informatik GK',
            teachers: [
              LessonTeacher(
                teacher: 'Caputo, Alessio',
                teacherKuerzel: 'CAP',
                email: 'a.caputo@schule.hessen.de',
                conversationReceiverId: 'l-316983',
              ),
              LessonTeacher(
                teacher: 'Weber, Anna',
                teacherKuerzel: 'WEB',
                email: 'a.weber@schule.hessen.de',
              ),
            ],
            history: const [],
            marks: const [],
            exams: const [],
            attendances: const {},
          );

          final studentParser = _FakeLessonsStudentParser(detailed);
          final parentParser = _FakeLessonsParentParser(detailed);
          addTearDown(studentParser.dispose);
          addTearDown(parentParser.dispose);

          ConversationComposeExtra? capturedExtra;
          await pumpTestRouterApp(
            tester,
            initialLocation: '/course',
            overrides: [
              sessionProvider.overrideWith(
                () => _ReadySession(supportsConversations: true),
              ),
              lessonsStudentParserProvider.overrideWithValue(studentParser),
              lessonsParentParserProvider.overrideWithValue(parentParser),
            ],
            routes: [
              GoRoute(
                path: '/course',
                builder: (context, state) => CourseOverviewAnsicht(
                  dataFetchURL: accountType == AccountType.parent
                      ? 'meinunterricht.php?a=sus_view&id=20&p=101'
                      : 'meinunterricht.php?a=sus_view&id=20',
                  title: 'Informatik GK',
                  accountType: accountType,
                  pupilName: accountType == AccountType.parent
                      ? 'Max Mustermann'
                      : null,
                ),
              ),
              GoRoute(
                path: conversationsComposePath,
                builder: (context, state) {
                  capturedExtra = state.extra as ConversationComposeExtra?;
                  return const Scaffold(body: Text('Compose Destination'));
                },
              ),
            ],
          );
          await tester.pumpAndSettle();

          final contactBtn = find.byIcon(Icons.chat_bubble_outline);
          expect(contactBtn, findsOneWidget);

          await tester.tap(contactBtn);
          await tester.pumpAndSettle();

          expect(find.text('Caputo, Alessio (CAP)'), findsOneWidget);
          expect(find.text('Weber, Anna (WEB)'), findsOneWidget);
          expect(find.text('Send message'), findsOneWidget);
          expect(find.text('Send email'), findsNWidgets(2));
          expect(find.text('a.caputo@schule.hessen.de'), findsOneWidget);
          expect(find.text('a.weber@schule.hessen.de'), findsOneWidget);

          await tester.tap(find.text('Send message'));
          await tester.pumpAndSettle();

          expect(find.text('Compose Destination'), findsOneWidget);
          expect(capturedExtra!.initialReceivers.single.id, 'l-316983');
          expect(
            capturedExtra!.initialReceivers.single.name,
            'Caputo, Alessio',
          );
        },
      );
    }

    testWidgets(
      'ConversationComposePage routes prefilled extra into NewConversationConfigurator',
      (tester) async {
        final parser = _FakeConversationsParser(cachedCanChooseType: false);
        addTearDown(parser.dispose);

        await pumpTestApp(
          tester,
          overrides: [conversationsParserProvider.overrideWithValue(parser)],
          child: ConversationComposePage(
            initialReceivers: [
              ReceiverEntry('l-316983', 'Caputo, Alessio', true),
            ],
            handleSubmission: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NewConversationConfigurator), findsOneWidget);
        expect(find.text('Caputo, Alessio'), findsOneWidget);
        expect(parser.searchTeacherCalls, 0);
      },
    );

    testWidgets(
      'deleting a prefilled receiver chip immediately disables Create FAB and hides Clear All',
      (tester) async {
        final parser = _FakeConversationsParser(cachedCanChooseType: false);
        addTearDown(parser.dispose);

        await pumpTestApp(
          tester,
          overrides: [conversationsParserProvider.overrideWithValue(parser)],
          child: NewConversationConfigurator(
            initialReceivers: [
              ReceiverEntry('l-105044', 'Müller, Max (MÜL)', true),
            ],
            initialSubject: 'Hello',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.clear_all), findsOneWidget);
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byType(FloatingActionButton),
              )
              .onPressed,
          isNotNull,
        );

        await tester.tap(find.byIcon(Icons.cancel));
        await tester.pumpAndSettle();

        expect(find.text('Müller, Max (MÜL)'), findsNothing);
        expect(find.byIcon(Icons.clear_all), findsNothing);
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byType(FloatingActionButton),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      'Lessons Course Detail shows email icon when only email is available',
      (tester) async {
        final detailed = DetailedLesson(
          courseID: '21',
          name: 'Physik GK',
          teachers: [
            LessonTeacher(
              teacher: 'Weber, Anna',
              teacherKuerzel: 'WEB',
              email: 'a.weber@schule.hessen.de',
            ),
          ],
          history: const [],
          marks: const [],
          exams: const [],
          attendances: const {},
        );
        final studentParser = _FakeLessonsStudentParser(detailed);
        addTearDown(studentParser.dispose);

        await pumpTestApp(
          tester,
          overrides: [
            sessionProvider.overrideWith(
              () => _ReadySession(supportsConversations: true),
            ),
            lessonsStudentParserProvider.overrideWithValue(studentParser),
          ],
          child: const CourseOverviewAnsicht(
            dataFetchURL: 'meinunterricht.php?a=sus_view&id=21',
            title: 'Physik GK',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.email_outlined), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      },
    );

    testWidgets(
      'DeepLinkPopScope with popGoRouterIfPossible returns to caller across ShellRoute',
      (tester) async {
        await pumpTestRouterApp(
          tester,
          initialLocation: '/origin',
          routes: [
            GoRoute(
              path: '/origin',
              builder: (context, state) => Scaffold(
                body: FilledButton(
                  onPressed: () => context.push('/shell/detail'),
                  child: const Text('Open'),
                ),
              ),
            ),
            GoRoute(
              path: '/fallback',
              builder: (context, state) =>
                  const Scaffold(body: Text('Fallback')),
            ),
            ShellRoute(
              builder: (context, state, child) => child,
              routes: [
                GoRoute(
                  path: '/shell/detail',
                  builder: (context, state) => const DeepLinkPopScope(
                    fallbackPath: '/fallback',
                    popGoRouterIfPossible: true,
                    child: Scaffold(body: Text('Shell Detail')),
                  ),
                ),
              ],
            ),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Shell Detail'), findsOneWidget);

        // Simulate system back press.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Fallback'), findsNothing);
      },
    );
  });
}
