import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/timetable_modifications_editor.dart';
import '../helpers/test_app.dart';
import '../helpers/timetable_fixture.dart';

void main() {
  tearDown(LanisClient.reset);
  Future<void> pump(WidgetTester tester, Map<String, dynamic> settings) async {
    tester.view.physicalSize = const Size(450, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTestApp(
      tester,
      child: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => TimetableModificationsEditor(
            timetable: timetable(),
            settings: settings,
            updateSettings: (key, value) async =>
                setState(() => settings[key] = value),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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
      await tester.tap(find.byKey(const ValueKey('custom-lesson-weekday')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thursday').last);
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
