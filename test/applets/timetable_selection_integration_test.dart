import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/timetable/student/student_timetable_better_view.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';
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

class _TimetableParser extends TimetableStudentParser {
  _TimetableParser(super.ctx);
  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {}

  void publish(String badge) {
    final hour = TimeTableRow(
      TimeTableRowType.lesson,
      const SphTimeOfDay(hour: 8, minute: 0),
      const SphTimeOfDay(hour: 8, minute: 45),
      '1',
      1,
    );
    TimetableSubject lesson(String name, String? badge) => TimetableSubject(
      id: name,
      name: name,
      raum: 'R1',
      lehrer: 'T',
      badge: badge,
      duration: 1,
      startTime: hour.startTime,
      endTime: hour.endTime,
      stunde: 1,
    );
    final daily = lesson('D', null);
    final wa = lesson('IT5', 'WA');
    final wb = lesson('GL', 'WB');
    addResponse(
      FetcherResponse(
        status: FetcherStatus.done,
        error: null,
        fetchedAt: DateTime(2026, 9, 13, 19, 30),
        content: TimeTable(
          weekBadge: badge,
          hours: [hour],
          planForOwn: [
            [wb],
            [wa],
            [daily],
            [daily],
            [daily],
          ],
          planForAll: [
            [wa],
            [wb],
            [daily],
            [daily],
            [daily],
          ],
        ),
      ),
    );
  }
}

Future<(_TimetableParser, TypedSettings, LanisSession)>
_createTimetable() async {
  final database = LanisDatabase.open();
  final accountId = await database.addAccount(
    schoolId: 1,
    schoolName: 'Test',
    username: 'test',
    password: 'test',
  );
  final account = ClearTextAccount(
    localId: accountId,
    schoolID: 1,
    username: 'test',
    password: 'test',
    schoolName: 'Test',
  );
  final session = LanisSession(
    account: account,
    config: const LanisConfig(),
    connectionChecker: _OnlineChecker(),
  );
  final settings = TypedSettings.account(database, accountId);
  final parser = _TimetableParser(
    AppletContext(
      session: session,
      database: database,
      account: account,
      accountSettings: settings,
    ),
  );
  addTearDown(() async {
    parser.dispose();
    await session.dispose();
    session.connectionChecker.dispose();
    database.dispose();
    LanisClient.reset();
  });
  parser.publish('WA');
  return (parser, settings, session);
}

void main() {
  for (final scenario in [
    'empty personal plan',
    'empty weekdays',
    'filtered week',
    'hidden lessons',
    'missing hours',
  ]) {
    testWidgets('#552 can return to general plan from $scenario', (
      tester,
    ) async {
      final (parser, settings, session) = await _createTimetable();
      final timetable = parser.latestResponse!.content!;
      switch (scenario) {
        case 'empty personal plan':
          timetable.planForOwn = [];
        case 'empty weekdays':
          timetable.planForOwn = List.generate(5, (_) => <TimetableSubject>[]);
        case 'filtered week':
          timetable.planForOwn = [timetable.planForOwn!.first];
        case 'hidden lessons':
          timetable.planForOwn = [timetable.planForOwn![1]];
          settings.setJsonList('stundenplan.php/hidden-lessons', ['IT5']);
        case 'missing hours':
          timetable.hours = [];
      }
      settings.setString(
        'stundenplan.php/student-selected-type',
        'TimeTableType.all',
      );
      await pumpTestApp(
        tester,
        child: const StudentTimetableBetterView(),
        overrides: [
          sessionProvider.overrideWith(() => _ReadySession(session)),
          timetableParserProvider.overrideWithValue(parser),
          accountSpecificSettingsProvider.overrideWithValue(settings),
        ],
      );
      await tester.pumpAndSettle();
      final button = find.byType(FloatingActionButton);
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        settings.getString('stundenplan.php/student-selected-type'),
        'TimeTableType.own',
      );
      expect(find.byIcon(Icons.sentiment_dissatisfied), findsOneWidget);
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.people)),
        findsOneWidget,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        settings.getString('stundenplan.php/student-selected-type'),
        'TimeTableType.all',
      );
      expect(button, findsOneWidget);
      if (scenario != 'missing hours') {
        expect(find.byIcon(Icons.sentiment_dissatisfied), findsNothing);
        expect(find.text('D'), findsNWidgets(3));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    '#552 does not offer switching when personal plan is unavailable',
    (tester) async {
      final (parser, settings, session) = await _createTimetable();
      parser.latestResponse!.content!.planForOwn = null;
      await pumpTestApp(
        tester,
        child: const StudentTimetableBetterView(),
        overrides: [
          sessionProvider.overrideWith(() => _ReadySession(session)),
          timetableParserProvider.overrideWithValue(parser),
          accountSpecificSettingsProvider.overrideWithValue(settings),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('IT5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'menu selection persists through plan switches, refreshes and remounts',
    (tester) async {
      final (parser, settings, session) = await _createTimetable();
      Future<void> mount() async {
        await pumpTestApp(
          tester,
          child: const StudentTimetableBetterView(),
          overrides: [
            sessionProvider.overrideWith(() => _ReadySession(session)),
            timetableParserProvider.overrideWithValue(parser),
            accountSpecificSettingsProvider.overrideWithValue(settings),
          ],
        );
        await tester.pumpAndSettle();
      }

      Future<void> choose(String label) async {
        await tester.tap(find.byType(PopupMenuButton<TimetableWeekSelection>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await mount();
      expect(find.text('IT5'), findsOneWidget);
      expect(find.text('GL'), findsNothing);
      expect(find.text('KW 37'), findsOneWidget);
      await choose('WB-Week');
      expect(find.text('GL'), findsOneWidget);
      expect(find.text('IT5'), findsNothing);
      expect(settings.getJsonMap('stundenplan.php/student-week-selection'), {
        'mode': 'badge',
        'badge': 'WB',
      });
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('GL'), findsOneWidget);
      expect(find.text('IT5'), findsNothing);
      parser.publish('WA');
      await tester.pumpAndSettle();
      expect(find.text('GL'), findsOneWidget);
      expect(find.text('IT5'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await mount();
      expect(find.text('GL'), findsOneWidget);
      expect(find.text('WB-Week'), findsNWidgets(2));
      await choose('Current week');
      expect(find.text('IT5'), findsOneWidget);
      parser.publish('WB');
      await tester.pumpAndSettle();
      expect(find.text('GL'), findsOneWidget);
      expect(find.text('IT5'), findsNothing);
      parser.publish('WA');
      await tester.pumpAndSettle();
      expect(find.text('IT5'), findsOneWidget);
      expect(find.text('GL'), findsNothing);
      await choose('All Weeks');
      expect(find.text('IT5'), findsOneWidget);
      expect(find.text('GL'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
