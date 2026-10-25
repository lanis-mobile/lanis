import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';

void main() {
  group('TimetableWeekSelection', () {
    test('migrates the legacy preference and saves explicit modes', () {
      for (final all in [false, true]) {
        final selection = TimetableWeekSelection.fromSettings({
          'student-selected-week': all,
          'student-week-selection': <String, dynamic>{},
        });
        expect(
          selection.mode,
          all ? TimetableWeekMode.all : TimetableWeekMode.current,
        );
        final restored = TimetableWeekSelection.fromSettings({
          'student-week-selection': selection.toJson(),
        });
        expect(restored.mode, selection.mode);
      }
    });

    test(
      'current mode follows refreshed server data; manual mode stays fixed',
      () {
        const current = TimetableWeekSelection.current();
        const manual = TimetableWeekSelection.badge('WA');
        expect(current.resolveBadge('WA'), 'WA');
        expect(current.resolveBadge('WB'), 'WB');
        expect(manual.resolveBadge('WB'), 'WA');
        expect(const TimetableWeekSelection.all().resolveBadge('WA'), isNull);
        expect(current.resolveBadge(null), isNull);
        expect(current.resolveBadge('  '), isNull);
      },
    );

    test(
      'manual badge survives settings reload and overrides legacy all weeks',
      () {
        final selection = TimetableWeekSelection.fromSettings({
          'student-selected-week': true,
          'student-week-selection': const TimetableWeekSelection.badge(
            'WB',
          ).toJson(),
        });
        expect(selection.mode, TimetableWeekMode.badge);
        expect(selection.resolveBadge('WA'), 'WB');
      },
    );

    test('invalid saved choices safely fall back to the legacy preference', () {
      for (final saved in [
        null,
        'bad',
        {'mode': 'badge', 'badge': 3},
        {'mode': 'badge', 'badge': ''},
        {'mode': 'unknown'},
      ]) {
        expect(
          TimetableWeekSelection.fromSettings({
            'student-week-selection': saved,
          }).mode,
          TimetableWeekMode.current,
        );
      }
    });

    test('Discord plan ordering cannot change the selected badge', () {
      // The report has WA lessons first in the general plan, but WB first in
      // the personal plan. Reproduce both directions and filtering results.
      TimetableSubject lesson(String name, String? badge) => TimetableSubject(
        id: name,
        name: name,
        raum: '',
        lehrer: '',
        badge: badge,
        duration: 1,
        startTime: const SphTimeOfDay(hour: 14, minute: 0),
        endTime: const SphTimeOfDay(hour: 14, minute: 45),
        stunde: 7,
      );
      final gl = lesson('GL', 'WB');
      final it = lesson('IT5', 'WA');
      final lrs = lesson('LRS', 'WA');
      final daily = lesson('D', null);
      final timetable = TimeTable(
        weekBadge: 'WA',
        hours: [],
        planForOwn: [
          [gl, it, daily],
        ],
        planForAll: [
          [lrs, gl, it, daily],
        ],
      );
      for (final selection in [
        const TimetableWeekSelection.current(),
        const TimetableWeekSelection.badge('WA'),
      ]) {
        for (final plan in [
          timetable.planForOwn!,
          timetable.planForAll!,
          timetable.planForOwn!,
        ]) {
          final data = TimeTableData(
            plan,
            timetable,
            {},
            selection.resolveBadge(timetable.weekBadge),
          );
          final names = data.timetableDays
              .expand((day) => day)
              .map((lesson) => lesson.name);
          expect(names, containsAll(['IT5', 'D']));
          expect(names, isNot(contains('GL')));
        }
      }
      // A manual badge absent from one plan is retained, rather than silently
      // switching to a different week or showing all weekly lessons.
      final data = TimeTableData(
        [
          [gl, daily],
        ],
        timetable,
        {},
        const TimetableWeekSelection.badge('WA').resolveBadge('WB'),
      );
      expect(data.timetableDays.single.map((s) => s.name), ['D']);
    });
  });

  group('displayed school week', () {
    test('Sunday stays in the server week and Monday advances', () {
      final sunday = timetableWeekStart(DateTime(2026, 9, 13, 19, 30));
      expect(sunday, DateTime(2026, 9, 7));
      expect(timetableWeekNumber(sunday), 37);
      final monday = timetableWeekStart(DateTime(2026, 9, 14));
      expect(monday, DateTime(2026, 9, 14));
      expect(timetableWeekNumber(monday), 38);
    });

    test('all seven weekdays use the same Monday', () {
      for (var day = 19; day <= 25; day++) {
        final start = timetableWeekStart(DateTime(2026, 10, day, 14));
        expect(start, DateTime(2026, 10, 19));
        expect(timetableWeekNumber(start), 43);
      }
    });

    test('ISO week boundaries work across year and leap-year boundaries', () {
      for (final entry in [
        (DateTime(2027, 1, 3), DateTime(2026, 12, 28), 53),
        (DateTime(2027, 1, 4), DateTime(2027, 1, 4), 1),
        (DateTime(2024, 12, 30), DateTime(2024, 12, 30), 1),
        (DateTime(2024, 3, 3), DateTime(2024, 2, 26), 9),
      ]) {
        final start = timetableWeekStart(entry.$1);
        expect(start, entry.$2);
        expect(timetableWeekNumber(start), entry.$3);
      }
    });
  });

  group('isTimetableVisuallyEmpty', () {
    test('hours present but days filtered empty is empty UI', () {
      expect(
        isTimetableVisuallyEmpty(hoursEmpty: false, daysEmpty: true),
        isTrue,
      );
      expect(
        isTimetableVisuallyEmpty(hoursEmpty: true, daysEmpty: false),
        isTrue,
      );
      expect(
        isTimetableVisuallyEmpty(hoursEmpty: false, daysEmpty: false),
        isFalse,
      );
    });
  });

  test('TimeTableData with unmatched weekBadge yields empty days', () {
    final hour = TimeTableRow(
      TimeTableRowType.lesson,
      const SphTimeOfDay(hour: 8, minute: 0),
      const SphTimeOfDay(hour: 8, minute: 45),
      '1',
      1,
    );
    final subject = TimetableSubject(
      id: 'm-0-0',
      name: 'Mathe',
      raum: 'R1',
      lehrer: 'Mu',
      badge: 'A',
      duration: 1,
      startTime: hour.startTime,
      endTime: hour.endTime,
      stunde: 0,
    );
    final timetable = TimeTable(
      planForAll: [
        [subject],
      ],
      hours: [hour],
      weekBadge: 'A',
    );

    final data = TimeTableData(
      [
        [subject],
      ],
      timetable,
      const {},
      'B', // filter to a week with no lessons
    );

    expect(data.hours, isNotEmpty);
    expect(data.timetableDays, isEmpty);
    expect(
      isTimetableVisuallyEmpty(
        hoursEmpty: data.hours.isEmpty,
        daysEmpty: data.timetableDays.isEmpty,
      ),
      isTrue,
    );
  });
}
