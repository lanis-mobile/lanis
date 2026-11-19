import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';
import '../helpers/timetable_fixture.dart';

void main() {
  test('calendar rules survive JSON and legacy entries remain weekly', () {
    final subject = lesson('Alternating', 8)
      ..calendarWeekParity = TimetableWeekParity.odd;
    final restored = TimetableSubject.fromJson(jsonDecode(jsonEncode(subject)));
    expect(restored, subject);
    expect(restored.badge, isNull);
    final legacy = subject.toJson()..remove('calendarWeekParity');
    expect(TimetableSubject.fromJson(legacy).calendarWeekParity, isNull);
  });

  test(
    'ISO parity follows displayed week through week 53 and year rollover',
    () {
      final weekly = lesson('Weekly', 8);
      final school = lesson('School A', 8)..badge = 'A';
      final even = lesson('Even', 8)
        ..calendarWeekParity = TimetableWeekParity.even;
      final odd = lesson('Odd', 8)
        ..calendarWeekParity = TimetableWeekParity.odd;
      final plan = [
        [weekly, school, even, odd],
        <TimetableSubject>[],
      ];
      for (final (date, expected) in [
        (DateTime(2020, 12, 21), even), // ISO week 52
        (DateTime(2021, 1, 1), odd), // ISO week 53 of previous year
        (DateTime(2021, 1, 4), odd), // ISO week 1
        (DateTime(2021, 1, 11), even), // ISO week 2
      ]) {
        final filtered = filterCalendarWeekLessons(plan, date);
        expect(filtered.first, [weekly, school, expected]);
        expect(filtered.last, isEmpty);
        expect(plan.first, hasLength(4)); // Never mutate the stored plan.
      }
    },
  );
}
