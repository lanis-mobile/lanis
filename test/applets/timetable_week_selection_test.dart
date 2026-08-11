import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';

void main() {
  group('resolveTimetableWeekSelection', () {
    test('stale index into empty badges falls back to all weeks', () {
      final result = resolveTimetableWeekSelection(
        currentWeekIndex: 2,
        uniqueBadges: const [],
      );

      expect(result.index, 0);
      expect(result.badge, isNull);
    });

    test('index beyond badge length falls back to all weeks', () {
      final result = resolveTimetableWeekSelection(
        currentWeekIndex: 5,
        uniqueBadges: const ['A', 'B'],
      );
      expect(result.index, 0);
      expect(result.badge, isNull);
    });

    test('valid index returns matching badge', () {
      final result = resolveTimetableWeekSelection(
        currentWeekIndex: 2,
        uniqueBadges: const ['A', 'B'],
      );
      expect(result.index, 2);
      expect(result.badge, 'B');
    });

    test('zero and negative indexes mean all weeks', () {
      expect(
        resolveTimetableWeekSelection(
          currentWeekIndex: 0,
          uniqueBadges: const ['A'],
        ).badge,
        isNull,
      );
      expect(
        resolveTimetableWeekSelection(
          currentWeekIndex: -1,
          uniqueBadges: const ['A'],
        ).index,
        0,
      );
    });
  });

  group('initialTimetableWeekIndex', () {
    test('unknown weekBadge does not produce negative/out-of-range index', () {
      expect(
        initialTimetableWeekIndex(
          showByWeek: false,
          weekBadge: 'Z',
          uniqueBadges: const ['A', 'B'],
        ),
        0,
      );
    });

    test('known weekBadge maps to 1-based index', () {
      expect(
        initialTimetableWeekIndex(
          showByWeek: false,
          weekBadge: 'B',
          uniqueBadges: const ['A', 'B'],
        ),
        2,
      );
    });

    test('showByWeek forces all-weeks index', () {
      expect(
        initialTimetableWeekIndex(
          showByWeek: true,
          weekBadge: 'A',
          uniqueBadges: const ['A'],
        ),
        0,
      );
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
