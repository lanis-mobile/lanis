class StudentStudyGroups {
  final List<StudentStudyGroup> groups;
  final List<StudentStudyGroupExam> exams;

  StudentStudyGroups({required this.groups, required this.exams});

  List<StudentStudyGroupExam> get sortedExams {
    return exams..sort((a, b) => a.date.compareTo(b.date));
  }
}

class StudentStudyGroup {
  final String id;
  final String semester;
  final String courseName;
  final String courseSysId;
  final List<StudentStudyGroupTeacher> teachers;
  final List<StudentStudyGroupExam> exams;

  StudentStudyGroup({
    required this.id,
    required this.semester,
    required this.courseName,
    required this.teachers,
    required this.exams,
    required this.courseSysId,
  });
}

class StudentStudyGroupTeacher {
  final String krz;
  final String firstName;
  final String lastName;
  final String? email;

  StudentStudyGroupTeacher({
    required this.krz,
    required this.firstName,
    required this.lastName,
    this.email,
  });
}

class StudentStudyGroupExam {
  final String id;
  final String courseId;
  final String courseName;
  final DateTime date;
  final String? durationLabel;
  final String? hoursOfDay;
  final String type;

  StudentStudyGroupExam({
    required this.id,
    required this.courseId,
    required this.date,
    required this.courseName,
    this.durationLabel,
    this.hoursOfDay,
    required this.type,
  });
}
