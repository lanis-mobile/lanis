import 'package:flutter/material.dart';
import 'package:lanis/applets/timetable/student/parser.dart';
import 'package:lanis/models/timetable.dart';

class DemoTimetableStudentParser extends TimetableStudentParser {
  DemoTimetableStudentParser(super.sph, super.appletDefinition);

  @override
  Future<TimeTable> getHome() async {
    final hours = [
      TimeTableRow(TimeTableRowType.lesson, const TimeOfDay(hour: 7, minute: 55), const TimeOfDay(hour: 8, minute: 40), '1', 0),
      TimeTableRow(TimeTableRowType.lesson, const TimeOfDay(hour: 8, minute: 45), const TimeOfDay(hour: 9, minute: 30), '2', 1),
      TimeTableRow(TimeTableRowType.pause,  const TimeOfDay(hour: 9, minute: 30), const TimeOfDay(hour: 9, minute: 50), 'Pause', 2),
      TimeTableRow(TimeTableRowType.lesson, const TimeOfDay(hour: 9, minute: 50), const TimeOfDay(hour: 10, minute: 35), '3', 3),
      TimeTableRow(TimeTableRowType.lesson, const TimeOfDay(hour: 10, minute: 40), const TimeOfDay(hour: 11, minute: 25), '4', 4),
      TimeTableRow(TimeTableRowType.pause,  const TimeOfDay(hour: 11, minute: 25), const TimeOfDay(hour: 11, minute: 40), 'Pause', 5),
      TimeTableRow(TimeTableRowType.lesson, const TimeOfDay(hour: 11, minute: 40), const TimeOfDay(hour: 12, minute: 25), '5', 6),
      TimeTableRow(TimeTableRowType.lesson, const TimeOfDay(hour: 12, minute: 30), const TimeOfDay(hour: 13, minute: 15), '6', 7),
    ];

    TimetableSubject s(String id, String name, String raum, String lehrer, int stunde) =>
        TimetableSubject(id: id, name: name, raum: raum, lehrer: lehrer,
            badge: null, duration: 1,
            startTime: () {
              final row = hours.where((h) => h.lessonIndex == stunde && h.type == TimeTableRowType.lesson);
              return row.isEmpty ? const TimeOfDay(hour: 8, minute: 0) : row.first.startTime;
            }(),
            endTime: () {
              final row = hours.where((h) => h.lessonIndex == stunde && h.type == TimeTableRowType.lesson);
              return row.isEmpty ? const TimeOfDay(hour: 8, minute: 45) : row.first.endTime;
            }(),
            stunde: stunde);

    final planForOwn = [
      [s('ma','Mathematik','204','Müller',0), s('de','Deutsch','101','Koch',1), s('en','Englisch','102','Weber',3), s('bi','Biologie','301','Fischer',4), s('sp','Sport','Sporthalle','Hoffmann',6), s('mu','Musik','103','Braun',7)],
      [s('ge','Geschichte','105','Schulz',0), s('ma','Mathematik','204','Müller',1), s('de','Deutsch','101','Koch',3), s('ph','Physik','302','Zimmermann',4), s('en','Englisch','102','Weber',6), s('ku','Kunst','104','Becker',7)],
      [s('bi','Biologie','301','Fischer',0), s('sp','Sport','Sporthalle','Hoffmann',1), s('ma','Mathematik','204','Müller',3), s('ge','Geschichte','105','Schulz',4), s('de','Deutsch','101','Koch',6), s('mu','Musik','103','Braun',7)],
      [s('en','Englisch','102','Weber',0), s('ph','Physik','302','Zimmermann',1), s('bi','Biologie','301','Fischer',3), s('ma','Mathematik','204','Müller',4), s('ku','Kunst','104','Becker',6), s('ge','Geschichte','105','Schulz',7)],
      [s('de','Deutsch','101','Koch',0), s('en','Englisch','102','Weber',1), s('sp','Sport','Sporthalle','Hoffmann',3), s('mu','Musik','103','Braun',4), s('ph','Physik','302','Zimmermann',6), s('ma','Mathematik','204','Müller',7)],
    ];

    return TimeTable(planForOwn: planForOwn, planForAll: null, hours: hours, weekBadge: null);
  }
}
