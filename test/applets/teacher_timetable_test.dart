import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/timetable/teacher/teacher_timetable_grid.dart';
import 'package:lanis/applets/timetable/teacher/teacher_timetable_models.dart';
import 'package:lanis/applets/timetable/teacher/teacher_timetable_panels.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

Widget _wrap(Widget child, {Size? size, double textScale = 1.0}) {
  return MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: size ?? const Size(800, 900),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: child),
    ),
  );
}

TimeTableRow _hour(int idx, int sh, int sm, int eh, int em) => TimeTableRow(
  TimeTableRowType.lesson,
  SphTimeOfDay(hour: sh, minute: sm),
  SphTimeOfDay(hour: eh, minute: em),
  '$idx',
  idx,
);

TeacherTimetableEntry _entry({
  required String id,
  TeacherTimetableEntryKind kind = TeacherTimetableEntryKind.regular,
  String? subject = 'Mathe',
  String? room = 'R102',
  List<String> classes = const ['5a'],
  List<String> teachers = const ['CAP'],
  String? supervisionLocation,
  String? badge,
  int duration = 1,
  int hourIndex = 1,
}) => TeacherTimetableEntry(
  id: id,
  kind: kind,
  subject: subject,
  room: room,
  classes: classes,
  teachers: teachers,
  supervisionLocation: supervisionLocation,
  badge: badge,
  duration: duration,
  startTime: const SphTimeOfDay(hour: 8, minute: 0),
  endTime: const SphTimeOfDay(hour: 8, minute: 45),
  hourIndex: hourIndex,
);

void main() {
  group('teacher_timetable_models', () {
    test('buildTeacherGridRows skips <=10min passing gaps and keeps real breaks & supervisions', () {
      final plan = TeacherTimetablePlan(
        category: TeacherTimetableCategory.teacher,
        targetId: 'CAP',
        title: 'CAP',
        weekdayIndices: const [0],
        hours: [
          _hour(1, 8, 0, 8, 45),
          // 5-minute passing period -> no pause row
          _hour(2, 8, 50, 9, 35),
          // 20-minute real break -> pause row
          _hour(3, 9, 55, 10, 40),
          // 0-minute gap, but has break supervision before hour 4 -> pause row
          _hour(4, 10, 40, 11, 25),
        ],
        days: [
          [
            _entry(
              id: 'sup4',
              kind: TeacherTimetableEntryKind.breakSupervision,
              subject: null,
              supervisionLocation: 'Hof',
              hourIndex: 4,
            ),
          ],
        ],
      );

      final rows = buildTeacherGridRows(plan);
      final kinds = rows.map((r) => r.kind).toList();
      expect(kinds, [
        TeacherGridRowKind.lesson,
        TeacherGridRowKind.lesson,
        TeacherGridRowKind.pause,
        TeacherGridRowKind.lesson,
        TeacherGridRowKind.pause,
        TeacherGridRowKind.lesson,
      ]);
    });

    test('filterTeacherDayByBadge keeps break supervisions, substitutions, and room bookings', () {
      final entries = [
        _entry(id: 'a', badge: 'A'),
        _entry(id: 'b', badge: 'B'),
        _entry(
          id: 'sub',
          kind: TeacherTimetableEntryKind.substitutionAdded,
          badge: 'B',
        ),
        _entry(
          id: 'rm',
          kind: TeacherTimetableEntryKind.roomBooking,
          badge: 'B',
        ),
        _entry(
          id: 'sup',
          kind: TeacherTimetableEntryKind.breakSupervision,
          supervisionLocation: 'Hof',
          badge: 'B',
        ),
      ];

      final filtered = filterTeacherDayByBadge(entries, 'A');
      expect(filtered.map((e) => e.id), ['a', 'sub', 'rm', 'sup']);
    });

    test('isRedundantLanisTooltip hides boilerplate but preserves real notes mentioning a room', () {
      expect(isRedundantLanisTooltip(null), isTrue);
      expect(isRedundantLanisTooltip('Mathe im Raum R102 (5a-M)'), isTrue);
      expect(
        isRedundantLanisTooltip('Mathe bei der Klasse/Stufe/Lerngruppe 5a'),
        isTrue,
      );
      expect(
        isRedundantLanisTooltip('Klausur entfällt. Bitte im Raum R102 melden!'),
        isFalse,
      );
    });
  });

  group('TeacherTimetableGrid & TeacherPlanCatalogPanel widgets', () {
    testWidgets('places overlapping multi-period lessons in side-by-side lanes without overflow at 1.4x text scale', (tester) async {
      final plan = TeacherTimetablePlan(
        category: TeacherTimetableCategory.teacher,
        targetId: 'CAP',
        title: 'CAP',
        weekdayIndices: const [0, 1],
        hours: [
          _hour(1, 8, 0, 8, 45),
          _hour(2, 8, 45, 9, 30),
        ],
        days: [
          [
            _entry(id: 'double', subject: 'Mathe', hourIndex: 1, duration: 2),
            _entry(
              id: 'overlap',
              kind: TeacherTimetableEntryKind.substitutionAdded,
              subject: 'Vertretung',
              hourIndex: 2,
              duration: 1,
            ),
          ],
          const [],
        ],
      );

      await tester.pumpWidget(
        _wrap(
          TeacherTimetableGrid(
            plan: plan,
            weekStart: DateTime(2026, 11, 23),
            onSelectEntry: (_, _) {},
          ),
          textScale: 1.4,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final mathRect = tester.getRect(find.text('Mathe'));
      final subRect = tester.getRect(find.text('Vertretung'));
      // Overlapping entries must be placed in distinct horizontal lanes.
      expect(mathRect.right <= subRect.left || subRect.right <= mathRect.left, isTrue);
    });

    testWidgets('single-day view handles mismatched weekdayIndices length safely', (tester) async {
      final plan = TeacherTimetablePlan(
        category: TeacherTimetableCategory.room,
        targetId: 'R102',
        title: 'R102',
        weekdayIndices: const [0],
        hours: [_hour(1, 8, 0, 8, 45)],
        days: [
          [_entry(id: 'd1', subject: 'Bio')],
          [_entry(id: 'd2', subject: 'Chemie')],
        ],
      );

      await tester.pumpWidget(
        _wrap(
          TeacherTimetableGrid(
            plan: plan,
            weekStart: DateTime(2026, 11, 23),
            singleDay: true,
            onSelectEntry: (_, _) {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Tab), findsNWidgets(2));
    });

    testWidgets('TeacherPlanCatalogPanel filters safely with Unicode characters and renders non-teacher chip wrap', (tester) async {
      final overview = TeacherTimetableOverview(
        teachers: [
          TeacherTimetableReference(
            category: TeacherTimetableCategory.teacher,
            id: 'CAP',
            label: 'Istanbul, Ali (CAP)',
            url: Uri.parse('https://start.schulportal.hessen.de/stundenplan.php?a=detail&t=CAP'),
          ),
        ],
        classes: [
          TeacherTimetableReference(
            category: TeacherTimetableCategory.schoolClass,
            id: '4b',
            label: '4b',
            url: Uri.parse('https://start.schulportal.hessen.de/stundenplan.php?a=detail_klasse&k=4b'),
          ),
        ],
        rooms: const [],
        breakSupervisions: const [],
        canViewOtherTeachers: true,
      );

      await tester.pumpWidget(
        _wrap(
          TeacherPlanCatalogPanel(
            overview: overview,
            ownTarget: null,
            activeTarget: null,
            expandedCategories: const {
              TeacherTimetableCategory.teacher,
              TeacherTimetableCategory.schoolClass,
            },
            onToggleCategory: (_) {},
            onSelectTarget: (_) {},
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'İstanbul');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('4b'), findsNothing);
    });

    testWidgets('no overflow at 320px/1.5x in single-day strip, agenda eyebrow, KW+weekBadge header, context banner, and inspector', (tester) async {
      final longBadge = 'VeryLongBadgeTextThatWouldOverflowNarrowContainers';
      final plan = TeacherTimetablePlan(
        category: TeacherTimetableCategory.teacher,
        targetId: 'CAP',
        title: 'CAP',
        weekBadge: 'A',
        noticeHtml: '<p>Hinweis</p>',
        validFromLabel: 'ab 23.11.2026 ' * 10,
        weekdayIndices: const [0, 1, 2, 3, 4],
        hours: [_hour(1, 8, 0, 8, 45)],
        days: [
          [
            _entry(id: 'e1', subject: 'Mathe', badge: longBadge),
            _entry(id: 'e2', subject: 'Physik', badge: longBadge),
          ],
          const [],
          const [],
          const [],
          const [],
        ],
      );
      final overview = TeacherTimetableOverview(
        teachers: const [],
        classes: const [],
        rooms: const [],
        breakSupervisions: const [],
        canViewOtherTeachers: false,
      );

      // 1. Single-day view (tabs + agenda eyebrow) at 320px, 1.5x text scale
      await tester.pumpWidget(
        _wrap(
          TeacherTimetableGrid(
            plan: plan,
            weekStart: DateTime(2026, 11, 23),
            singleDay: true,
            compact: true,
            onSelectEntry: (_, _) {},
          ),
          size: const Size(320, 640),
          textScale: 1.5,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 2. Week view KW + weekBadge header at 1280px, 1.5x text scale
      await tester.pumpWidget(
        _wrap(
          TeacherTimetableGrid(
            plan: plan,
            weekStart: DateTime(2026, 11, 23),
            selectedBadge: 'A',
            onSelectEntry: (_, _) {},
          ),
          size: const Size(1280, 800),
          textScale: 1.5,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 3. Context banner with very long validFromLabel
      await tester.pumpWidget(
        _wrap(
          TeacherPlanContextBanner(plan: plan),
          size: const Size(320, 200),
          textScale: 1.5,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 4. Inspector with negative dayColumnIndex & long hero/sibling eyebrow
      await tester.pumpWidget(
        _wrap(
          TeacherEntryInspectorPanel(
            plan: plan,
            overview: overview,
            selection: TeacherEntrySelection(
              dayColumnIndex: -1,
              entry: plan.days[0].first,
            ),
            weekStart: DateTime(2026, 11, 23),
            onOpenTarget: (_) {},
            onSelectSibling: (_) {},
            onClose: () {},
          ),
          size: const Size(252, 700),
          textScale: 1.5,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _wrap(
          TeacherEntryInspectorPanel(
            plan: plan,
            overview: overview,
            selection: TeacherEntrySelection(
              dayColumnIndex: 0,
              entry: plan.days[0].first,
            ),
            weekStart: DateTime(2026, 11, 23),
            onOpenTarget: (_) {},
            onSelectSibling: (_) {},
            onClose: () {},
          ),
          size: const Size(252, 700),
          textScale: 1.5,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
