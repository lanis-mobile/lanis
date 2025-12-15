import 'package:lanis/applets/calendar/definition.dart';
import 'package:lanis/applets/calendar/parser.dart';
import 'package:lanis/applets/conversations/definition.dart';
import 'package:lanis/applets/conversations/parser.dart';
import 'package:lanis/applets/data_storage/definition.dart';
import 'package:lanis/applets/data_storage/parser.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/applets/lessons/student/parser.dart';
import 'package:lanis/applets/lessons/teacher/parser.dart';
import 'package:lanis/applets/study_groups/definitions.dart';
import 'package:lanis/applets/study_groups/student/parser.dart';
import 'package:lanis/applets/substitutions/definition.dart';
import 'package:lanis/applets/substitutions/parser.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/applets/timetable/student/parser.dart';
import 'package:lanis/core/sph/sph.dart';

class Parsers {
  SPH sph;

  SubstitutionsParser? _substitutionsParser;
  CalendarParser? _calendarParser;
  LessonsStudentParser? _lessonsStudentParser;
  LessonsTeacherParser? _lessonsTeacherParser;
  DataStorageParser? _dataStorageParser;
  TimetableStudentParser? _timetableStudentParser;
  ConversationsParser? _conversationsParser;
  StudyGroupsStudentParser? _studyGroupsStudentParser;

  Parsers({required this.sph});

  SubstitutionsParser get substitutionsParser {
    _substitutionsParser ??= SubstitutionsParser(sph, substitutionDefinition);
    return _substitutionsParser!;
  }

  CalendarParser get calendarParser {
    _calendarParser ??= CalendarParser(sph, calendarDefinition);
    return _calendarParser!;
  }

  LessonsStudentParser get lessonsStudentParser {
    _lessonsStudentParser ??= LessonsStudentParser(sph, lessonsDefinition);
    return _lessonsStudentParser!;
  }

  LessonsTeacherParser get lessonsTeacherParser {
    _lessonsTeacherParser ??= LessonsTeacherParser(sph, lessonsDefinition);
    return _lessonsTeacherParser!;
  }

  DataStorageParser get dataStorageParser {
    _dataStorageParser ??= DataStorageParser(sph, dataStorageDefinition);
    return _dataStorageParser!;
  }

  TimetableStudentParser get timetableStudentParser {
    _timetableStudentParser ??=
        TimetableStudentParser(sph, timeTableDefinition);
    return _timetableStudentParser!;
  }

  ConversationsParser get conversationsParser {
    _conversationsParser ??= ConversationsParser(sph, conversationsDefinition);
    return _conversationsParser!;
  }

  StudyGroupsStudentParser get studyGroupsStudentParser {
    _studyGroupsStudentParser ??=
        StudyGroupsStudentParser(sph, studyGroupsDefinition);
    return _studyGroupsStudentParser!;
  }
}
