class StudentStudyGroups {
  final String halfYear;
  final String courseName;
  final String teacher;
  final String teacherKuerzel;
  final List<StudentExam>? exams;
  final Uri? email;
  final ({String name, String url})? picture;

  StudentStudyGroups(
      {required this.halfYear,
      required this.courseName,
      required this.teacher,
      required this.teacherKuerzel,
      required this.exams,
      this.email,
      this.picture});

  factory StudentStudyGroups.fromJson(Map<String, dynamic> json) {
    return StudentStudyGroups(
      halfYear: json['halfYear'],
      courseName: json['courseName'],
      teacher: json['teacher'],
      teacherKuerzel: json['teacherKuerzel'],
      picture: json['picture'] != null
          ? (
              name: json['picture']['name'],
              url: json['picture']['url'],
            )
          : null,
      email: json['email'] != null ? Uri.parse(json['email']) : null,
      exams:
          (json['exams'] as List).map((e) => StudentExam.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'halfYear': halfYear,
      'courseName': courseName,
      'teacher': teacher,
      'teacherKuerzel': teacherKuerzel,
      'picture': picture != null
          ? {
              'name': picture!.name,
              'url': picture!.url,
            }
          : null,
      'email': email?.path,
      'exams': exams?.map((e) => e.toJson()).toList(),
    };
  }
}

class StudentExam {
  final DateTime date;
  final String time;
  final String type;
  final String duration;

  StudentExam(
      {required this.date,
      required this.time,
      required this.type,
      required this.duration});

  factory StudentExam.fromJson(Map<String, dynamic> json) {
    return StudentExam(
      date: DateTime.parse(json['day']),
      duration: json['duration'],
      time: json['time'],
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': date.toIso8601String(),
      'duration': duration,
      'time': time,
      'type': type,
    };
  }
}

class StudentStudyGroupsContainer {
  final String halfYear;
  final String courseName;
  final String teacher;
  final String teacherKuerzel;
  final StudentExam exam;

  StudentStudyGroupsContainer(
      {required this.halfYear,
      required this.courseName,
      required this.teacher,
      required this.teacherKuerzel,
      required this.exam});
}

class StudentStudyGroupsData {
  final List<String> headers;
  final List<List<String>> data;

  StudentStudyGroupsData(this.headers, this.data);
}
