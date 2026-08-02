import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/lessons/student/attendances.dart';

Lesson _lesson({
  required String id,
  Map<String, String>? attendances,
}) {
  return Lesson(
    courseID: id,
    name: 'Course $id',
    teachers: const [],
    courseURL: Uri.parse('https://example.test/$id'),
    attendances: attendances,
  );
}

void main() {
  test('getCombinedAttendances skips lessons with null attendances', () {
    final combined = getCombinedAttendances([
      _lesson(id: 'a', attendances: {'fehlend': '1', 'entschuldigt': '2'}),
      _lesson(id: 'b'),
      _lesson(id: 'c', attendances: {'fehlend': '3'}),
    ]);

    expect(combined, {'fehlend': '4', 'entschuldigt': '2'});
  });

  test('getCombinedAttendances returns empty map when all null', () {
    expect(
      getCombinedAttendances([_lesson(id: 'a'), _lesson(id: 'b')]),
      isEmpty,
    );
  });
}
