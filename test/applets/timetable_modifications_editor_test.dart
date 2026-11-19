import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/timetable_modifications_editor.dart';
import '../helpers/test_app.dart';
import '../helpers/timetable_fixture.dart';

void main() {
  tearDown(LanisClient.reset);
  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> settings, {
    TimeTable? plan,
  }) async {
    tester.view.physicalSize = const Size(450, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTestApp(
      tester,
      child: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => TimetableModificationsEditor(
            timetable: plan ?? timetable(),
            settings: settings,
            updateSettings: (key, value) async =>
                setState(() => settings[key] = value),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('week rules are available without school badges and editable', (
    tester,
  ) async {
    final settings = <String, dynamic>{};
    await pump(tester, settings);
    await tester.tap(find.byKey(const ValueKey('add-custom-lesson')));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(7));
    await tester.enterText(
      find.byKey(const ValueKey('custom-lesson-name')),
      'Parity lesson',
    );
    await tester.tap(find.byKey(const ValueKey('custom-lesson-weekday-0')));
    final week = find.byKey(const ValueKey('custom-lesson-week'));
    await tester.ensureVisible(week);
    await tester.tap(
      find.descendant(of: week, matching: find.byType(TextField)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Even calendar weeks').last);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save-custom-lesson'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final entry =
        (settings['custom-lessons'] as List).first.single as TimetableSubject;
    expect(entry.calendarWeekParity, TimetableWeekParity.even);
    expect(entry.badge, isNull);
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: week, matching: find.byType(TextField)),
          )
          .controller!
          .text,
      'Even calendar weeks',
    );
    await tester.ensureVisible(week);
    await tester.tap(
      find.descendant(of: week, matching: find.byType(TextField)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('-').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final cleared =
        (settings['custom-lessons'] as List).first.single as TimetableSubject;
    expect(cleared.calendarWeekParity, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'school badges coexist with calendar rules and replace them on edit',
    (tester) async {
      final plan = timetable();
      plan.planForAll!.first.first.badge = 'A';
      final entry = lesson('Odd entry', 8)
        ..calendarWeekParity = TimetableWeekParity.odd;
      final settings = <String, dynamic>{
        'custom-lessons': [
          [entry],
        ],
      };
      await pump(tester, settings, plan: plan);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      final week = find.byKey(const ValueKey('custom-lesson-week'));
      await tester.ensureVisible(week);
      await tester.tap(
        find.descendant(of: week, matching: find.byType(TextField)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Even calendar weeks').last, findsOneWidget);
      expect(find.text('Odd calendar weeks').last, findsOneWidget);
      await tester.tap(find.text('A-Week').last);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('save-custom-lesson'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final saved =
          (settings['custom-lessons'] as List).first.single as TimetableSubject;
      expect(saved.badge, 'A');
      expect(saved.calendarWeekParity, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'one list sorts entries by weekday and time and omits an empty hidden section',
    (tester) async {
      await pump(tester, {
        'custom-lessons': [
          [lesson('Monday late', 9), lesson('Monday early', 8)],
          [],
          [lesson('Wednesday', 8)],
        ],
        'hidden-lessons': <String>[],
      });
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Hidden lessons'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Monday early')).dy,
        lessThan(tester.getTopLeft(find.text('Monday late')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Monday late')).dy,
        lessThan(tester.getTopLeft(find.text('Wednesday')).dy),
      );
      expect(find.byType(Card), findsNWidgets(3));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'hidden lessons follow custom entries and restoring the last removes the section',
    (tester) async {
      final settings = <String, dynamic>{
        'custom-lessons': [
          [lesson('Custom entry', 8)],
        ],
        'hidden-lessons': ['maths'],
      };
      await pump(tester, settings);
      expect(
        tester.getTopLeft(find.text('Custom entry')).dy,
        lessThan(tester.getTopLeft(find.text('Hidden lessons')).dy),
      );
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(settings['hidden-lessons'], isEmpty);
      expect(find.text('Hidden lessons'), findsNothing);
      expect(find.text('School maths'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'editing can move an entry to another weekday without duplicating it',
    (tester) async {
      final settings = <String, dynamic>{
        'custom-lessons': [
          [lesson('Original', 8)],
        ],
        'hidden-lessons': <String>[],
      };
      await pump(tester, settings);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('custom-lesson-name')),
        'Renamed',
      );
      await tester.tap(find.byKey(const ValueKey('custom-lesson-weekday-3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-custom-lesson')),
      );
      await tester.tap(find.byKey(const ValueKey('save-custom-lesson')));
      await tester.pumpAndSettle();
      final days = settings['custom-lessons'] as List;
      expect(days[0], isEmpty);
      expect((days[3] as List).single.name, 'Renamed');
      expect(find.text('Original'), findsNothing);
      expect(find.text('Renamed'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      expect((settings['custom-lessons'] as List)[3], isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
