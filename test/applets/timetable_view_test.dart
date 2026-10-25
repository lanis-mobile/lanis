import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/timetable/student/student_timetable_better_view.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  for (final scenario in ['current', 'past', 'other badge']) {
    testWidgets('live time marker is correct for $scenario week', (
      tester,
    ) async {
      final now = DateTime.now();
      final start = SphTimeOfDay(hour: now.hour, minute: 0);
      final end = SphTimeOfDay(hour: now.hour, minute: 59);
      final timetable = TimeTable(
        weekBadge: 'WA',
        hours: [TimeTableRow(TimeTableRowType.lesson, start, end, '1', 1)],
      );
      final lesson = TimetableSubject(
        id: 'd',
        name: 'D',
        raum: '',
        lehrer: '',
        badge: null,
        duration: 1,
        startTime: start,
        endTime: end,
        stunde: 1,
      );
      final data = TimeTableData(
        [
          [lesson],
        ],
        timetable,
        {},
        scenario == 'other badge' ? 'WB' : 'WA',
      );
      final week = timetableWeekStart(now);
      final displayedWeek = scenario == 'past'
          ? DateTime(week.year, week.month, week.day - 7)
          : week;
      await pumpTestApp(
        tester,
        child: Scaffold(
          body: Stack(
            children: [
              TimeMarkerWidget(
                data: data,
                timetable: timetable,
                settings: const {},
                weekStart: displayedWeek,
                day: now.weekday - 1,
              ),
            ],
          ),
        ),
      );
      expect(
        find.byType(Positioned),
        scenario == 'current' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final badge in ['WA', 'WB', null]) {
    testWidgets('Sunday grid uses one week and the effective $badge filter', (
      tester,
    ) async {
      final hour = TimeTableRow(
        TimeTableRowType.lesson,
        const SphTimeOfDay(hour: 8, minute: 0),
        const SphTimeOfDay(hour: 8, minute: 45),
        '1',
        1,
      );
      final lesson = TimetableSubject(
        id: 'd',
        name: 'D',
        raum: 'R1',
        lehrer: 'T',
        badge: null,
        duration: 1,
        startTime: hour.startTime,
        endTime: hour.endTime,
        stunde: 1,
      );
      final plan = List.generate(5, (_) => [lesson]);
      final timetable = TimeTable(
        weekBadge: 'WA',
        hours: [hour],
        planForAll: plan,
      );
      await pumpTestApp(
        tester,
        child: Scaffold(
          body: TimeTableView(
            data: TimeTableData(plan, timetable, {}, badge),
            timetable: timetable,
            weekStart: timetableWeekStart(DateTime(2026, 9, 13, 19, 30)),
            settings: const {},
            updateSettings: (_, _) {},
          ),
        ),
      );
      expect(find.text('KW 37'), findsOneWidget);
      for (final date in ['07.09.', '08.09.', '09.09.', '10.09.', '11.09.']) {
        expect(find.text(date), findsOneWidget);
      }
      expect(find.text('14.09.'), findsNothing);
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>();
      // The corner uses the effective filter, not the server's WA when WB or
      // all weeks are selected. Read the actual localized label from the view.
      expect(
        labels.where((s) => s.contains('WA') || s.contains('WB')),
        badge == null ? isEmpty : ['$badge-Week'],
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
