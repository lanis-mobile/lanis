import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/student/timetable_helper.dart';
import 'package:lanis/utils/applet_settings.dart';
import 'package:lanis/utils/random_color.dart';

TimetableSubject _lesson({required String id, required String name}) {
  return TimetableSubject(
    id: id,
    name: name,
    raum: null,
    lehrer: null,
    badge: null,
    duration: 1,
    startTime: SphTimeOfDay(hour: 8, minute: 0),
    endTime: SphTimeOfDay(hour: 8, minute: 45),
    stunde: 1,
  );
}

void main() {
  group('persistAppletSetting / resolveStoredAppletSetting', () {
    late LanisDatabase db;
    late TypedSettings settings;

    setUp(() {
      db = LanisDatabase.open();
      settings = TypedSettings.shared(db);
    });

    tearDown(() {
      db.dispose();
    });

    test('persists Map<String, String?> as a JSON map (not toString)', () {
      // Mimics color-picker clears that previously failed `is Map<String, dynamic>`.
      final colors = <String, String?>{'secabc': null, 'secdef': 'FF112233'};
      persistAppletSetting(settings, 'stundenplan.php/lesson-colors', colors);

      final loaded = resolveStoredAppletSetting(
        settings,
        'stundenplan.php/lesson-colors',
        <String, dynamic>{},
      );
      expect(loaded, isA<Map>());
      expect((loaded as Map)['secdef'], 'FF112233');
      expect(loaded.containsKey('secabc'), isTrue);
      expect(loaded['secabc'], isNull);
    });

    test('recovers from corrupted Map.toString() storage as empty default', () {
      settings.setString(
        'stundenplan.php/lesson-colors',
        '{sa4ca70bd0e42bfe29d4a12a94e5ba4f6: FF112233}',
      );

      final loaded = resolveStoredAppletSetting(
        settings,
        'stundenplan.php/lesson-colors',
        <String, dynamic>{},
      );
      expect(loaded, isA<Map>());
      expect((loaded as Map), isEmpty);
      expect(settings.getString('stundenplan.php/lesson-colors'), isNull);
    });

    test('does not treat map-default keys as bools', () {
      settings.setString('stundenplan.php/lesson-colors', 'not-a-bool');
      final loaded = resolveStoredAppletSetting(
        settings,
        'stundenplan.php/lesson-colors',
        <String, dynamic>{},
      );
      expect(loaded, isA<Map>());
      expect(loaded, isEmpty);
    });
  });

  group('TimeTableHelper.getColorForLesson', () {
    test('tolerates corrupted bool lesson-colors without throwing', () {
      final lesson = _lesson(
        id: 'sa4ca70bd0e42bfe29d4a12a94e5ba4f6-1',
        name: 'Mathe',
      );
      final color = TimeTableHelper.getColorForLesson({
        'lesson-colors': false,
      }, lesson);
      expect(color, RandomColor.bySeed('Mathe').primary);
    });

    test('reads stored hex colors', () {
      final lesson = _lesson(
        id: 'secabc-2',
        name: 'Deutsch',
      );
      final color = TimeTableHelper.getColorForLesson({
        'lesson-colors': {'secabc': 'FF112233'},
      }, lesson);
      expect(color, const Color(0xFF112233));
    });
  });
}
