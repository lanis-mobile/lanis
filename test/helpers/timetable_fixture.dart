import 'package:liblanis/liblanis.dart';

TimetableSubject lesson(String name, int hour, {String? id}) =>
    TimetableSubject(
      raum: null,
      lehrer: null,
      badge: null,
      id: id ?? name,
      name: name,
      duration: 1,
      stunde: 0,
      startTime: SphTimeOfDay(hour: hour, minute: 0),
      endTime: SphTimeOfDay(hour: hour, minute: 45),
    );

TimeTable timetable() => TimeTable(
  hours: [
    for (var h = 8; h <= 9; h++)
      TimeTableRow(
        TimeTableRowType.lesson,
        SphTimeOfDay(hour: h, minute: 0),
        SphTimeOfDay(hour: h, minute: 45),
        '${h - 7}',
        h - 7,
      ),
  ],
  planForAll: [
    [lesson('School maths', 8, id: 'maths')],
    [],
    [],
    [],
    [],
  ],
);
