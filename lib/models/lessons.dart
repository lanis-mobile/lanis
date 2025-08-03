import '../utils/file_operations.dart';

typedef Lessons = List<Lesson>;

class Lesson {
  String courseID;
  String name;
  Uri courseURL;
  List<LessonTeacher> teachers;
  Map<String, String>? attendances;
  CurrentEntry? currentEntry;

  Lesson(
      {required this.courseID,
      required this.name,
      required this.teachers,
      required this.courseURL,
      this.attendances,
      this.currentEntry});
}

class LessonTeacher {
  String? teacher;
  String? teacherKuerzel;

  LessonTeacher({this.teacher, this.teacherKuerzel});
}

class DetailedLesson {
  String courseID;
  String name;
  List<LessonTeacher> teachers;
  List<CurrentEntry> history;
  List<LessonMark> marks;
  List<LessonExam> exams;
  Map<String, String> attendances;
  Uri? semester1URL;

  DetailedLesson(
      {required this.courseID,
      required this.name,
      required this.teachers,
      required this.history,
      required this.marks,
      required this.exams,
      required this.attendances,
      this.semester1URL});
}

class LessonExam {
  String name;
  String? value;

  LessonExam({required this.name, this.value});
}

class LessonMark {
  String name;
  String date;
  String mark;
  String? comment;

  LessonMark(
      {required this.name,
      required this.date,
      required this.mark,
      this.comment});
}

class CurrentEntry {
  String entryID;
  String? topicTitle;
  String? description;
  DateTime? topicDate;
  String? schoolHours;
  Homework? homework;
  String? presence;
  List<FileInfo> files;
  List<LessonUpload> uploads;

  CurrentEntry(
      {required this.entryID,
      required this.files,
      required this.uploads,
      this.presence,
      this.topicTitle,
      this.topicDate,
      this.homework,
      this.schoolHours,
      this.description});
}

class Homework {
  String description;
  bool homeWorkDone;

  Homework({required this.description, required this.homeWorkDone});
}

class LessonUpload {
  String name;
  String status; //todo @kurwjan replace with enum
  Uri url;
  String? uploaded;
  String? date; //todo @kurwjan replace with DateTime

  LessonUpload(
      {required this.name,
      required this.status,
      required this.url,
      this.uploaded,
      this.date});
}

class UploadFile {
  final String name;
  final String url;
  final String index;

  UploadFile({required this.name, required this.url, required this.index});
}

class OwnFile extends UploadFile {
  final String time;
  final String? comment;

  OwnFile(
      {required super.name,
      required super.url,
      required super.index,
      required this.time,
      this.comment});
}

class PublicFile extends UploadFile {
  final String person;

  PublicFile(
      {required super.name,
      required super.url,
      required super.index,
      required this.person});
}

class FileStatus {
  final String name;
  final String status; //erfolgreich or fehlgeschlagen
  final String? message;

  FileStatus({required this.name, required this.status, this.message});
}
