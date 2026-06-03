import 'package:flutter/foundation.dart';
import 'package:lanis/applets/calendar/definition.dart';
import 'package:lanis/applets/conversations/definition.dart';
import 'package:lanis/applets/data_storage/definition.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/applets/study_groups/definitions.dart';
import 'package:lanis/applets/substitutions/definition.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/core/demo/demo_calendar_parser.dart';
import 'package:lanis/core/demo/demo_conversations_parser.dart';
import 'package:lanis/core/demo/demo_data_storage_parser.dart';
import 'package:lanis/core/demo/demo_lessons_student_parser.dart';
import 'package:lanis/core/demo/demo_study_groups_parser.dart';
import 'package:lanis/core/demo/demo_substitutions_parser.dart';
import 'package:lanis/core/demo/demo_timetable_parser.dart';
import 'package:lanis/core/sph/parsers.dart';
import 'package:lanis/applets/calendar/parser.dart';
import 'package:lanis/applets/conversations/parser.dart';
import 'package:lanis/applets/data_storage/parser.dart';
import 'package:lanis/applets/lessons/student/parser.dart';
import 'package:lanis/applets/study_groups/student/parser.dart';
import 'package:lanis/applets/substitutions/parser.dart';
import 'package:lanis/applets/timetable/student/parser.dart';

// Debug-only: all entry points are guarded by kDebugMode checks.
class DemoParsers extends Parsers {
  DemoParsers({required super.sph}) : assert(kDebugMode);

  @override
  SubstitutionsParser get substitutionsParser =>
      DemoSubstitutionsParser(sph, substitutionDefinition);

  @override
  CalendarParser get calendarParser =>
      DemoCalendarParser(sph, calendarDefinition);

  @override
  TimetableStudentParser get timetableStudentParser =>
      DemoTimetableStudentParser(sph, timeTableDefinition);

  @override
  LessonsStudentParser get lessonsStudentParser =>
      DemoLessonsStudentParser(sph, lessonsDefinition);

  @override
  ConversationsParser get conversationsParser =>
      DemoConversationsParser(sph, conversationsDefinition);

  @override
  DataStorageParser get dataStorageParser =>
      DemoDataStorageParser(sph, dataStorageDefinition);

  @override
  StudyGroupsStudentParser get studyGroupsStudentParser =>
      DemoStudyGroupsStudentParser(sph, studyGroupsDefinition);
}
