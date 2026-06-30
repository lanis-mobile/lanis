import 'package:lanis/applets/study_groups/student/parser.dart';
import 'package:lanis/core/demo/demo_fetch_mixin.dart';
import 'package:lanis/models/study_groups.dart';

class DemoStudyGroupsStudentParser extends StudyGroupsStudentParser with DemoFetchMixin<StudentStudyGroups> {
  DemoStudyGroupsStudentParser(super.sph, super.appletDefinition);

  @override
  Future<StudentStudyGroups> getHome() async {
    final teacher1 = StudentStudyGroupTeacher(
      krz: 'MÜL', firstName: 'Hans', lastName: 'Müller',
      email: 'mueller@demo-schule.de',
    );
    final teacher2 = StudentStudyGroupTeacher(
      krz: 'WEB', firstName: 'Anna', lastName: 'Weber',
      email: 'weber@demo-schule.de',
    );

    final exam1 = StudentStudyGroupExam(
      id: 'exam-1',
      courseId: 'demo-ma-lk',
      courseName: 'Mathematik LK',
      date: DateTime.now().add(const Duration(days: 14)),
      durationLabel: '180 Min.',
      hoursOfDay: '1–4',
      type: 'Klausur',
    );
    final exam2 = StudentStudyGroupExam(
      id: 'exam-2',
      courseId: 'demo-en-gk',
      courseName: 'Englisch GK',
      date: DateTime.now().add(const Duration(days: 21)),
      durationLabel: '90 Min.',
      hoursOfDay: '3–4',
      type: 'Klausur',
    );

    return StudentStudyGroups(
      groups: [
        StudentStudyGroup(
          id: 'demo-ma-lk',
          semester: '2025/26 – 1. Halbjahr',
          courseName: 'Mathematik Leistungskurs',
          courseSysId: 'ma-lk-1',
          teachers: [teacher1],
          exams: [exam1],
        ),
        StudentStudyGroup(
          id: 'demo-en-gk',
          semester: '2025/26 – 1. Halbjahr',
          courseName: 'Englisch Grundkurs',
          courseSysId: 'en-gk-1',
          teachers: [teacher2],
          exams: [exam2],
        ),
      ],
      exams: [exam1, exam2],
    );
  }
}
