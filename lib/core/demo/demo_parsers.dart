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

  DemoSubstitutionsParser? _demoSubstitutionsParser;
  DemoCalendarParser? _demoCalendarParser;
  DemoTimetableStudentParser? _demoTimetableParser;
  DemoLessonsStudentParser? _demoLessonsStudentParser;
  DemoConversationsParser? _demoConversationsParser;
  DemoDataStorageParser? _demoDataStorageParser;
  DemoStudyGroupsStudentParser? _demoStudyGroupsParser;

  @override
  SubstitutionsParser get substitutionsParser =>
      _demoSubstitutionsParser ??= DemoSubstitutionsParser(sph, substitutionDefinition);

  @override
  CalendarParser get calendarParser =>
      _demoCalendarParser ??= DemoCalendarParser(sph, calendarDefinition);

  @override
  TimetableStudentParser get timetableStudentParser =>
      _demoTimetableParser ??= DemoTimetableStudentParser(sph, timeTableDefinition);

  @override
  LessonsStudentParser get lessonsStudentParser =>
      _demoLessonsStudentParser ??= DemoLessonsStudentParser(sph, lessonsDefinition);

  @override
  ConversationsParser get conversationsParser =>
      _demoConversationsParser ??= DemoConversationsParser(sph, conversationsDefinition);

  @override
  DataStorageParser get dataStorageParser =>
      _demoDataStorageParser ??= DemoDataStorageParser(sph, dataStorageDefinition);

  @override
  StudyGroupsStudentParser get studyGroupsStudentParser =>
      _demoStudyGroupsParser ??= DemoStudyGroupsStudentParser(sph, studyGroupsDefinition);
}
