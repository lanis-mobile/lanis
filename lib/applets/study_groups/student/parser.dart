import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:lanis/core/applet_parser.dart';
import 'package:lanis/models/study_groups.dart';

class StudyGroupsStudentParser extends AppletParser<StudentStudyGroups> {
  StudyGroupsStudentParser(super.sph, super.appletDefinition);

  @override
  Future<StudentStudyGroups> getHome() async {
    Response response = await sph.session.dio
        .get('https://start.schulportal.hessen.de/lerngruppen.php');

    Document document = parse(response.data);

    Element? courses = document.getElementById('LGs');
    Element? exams = document.getElementById('klausuren');

    List<StudentStudyGroupExam> studyGroupExams = [];
    if (exams != null) {
      List<String> examTableHead = [];
      exams.querySelectorAll('thead tr th').forEach((element) {
        examTableHead.add(element.text.trim());
      });

      for (final Element examTableRow in exams
          .querySelectorAll('tbody tr')
          .where((row) => row.attributes['data-type'] == 'klausur')) {
        String courseId = examTableRow.attributes['data-lerngruppe']!;
        String id = examTableRow.attributes['data-id']!;

        Element? elementInRow(String key) {
          int index = examTableHead.indexOf(key);
          if (index == -1) return null;
          if (index >= examTableRow.children.length) return null;
          return examTableRow.children[index];
        }

        RegExp dateRegex = RegExp(r'.\d{2}\.\d{2}\.\d{4}');
        String dateString =
            dateRegex.stringMatch(elementInRow('Datum')!.text.trim())!.trim();
        dateString = dateString.split('.').reversed.join('-');
        elementInRow('Kurs')?.querySelector('small')?.innerHtml = '';
        studyGroupExams.add(StudentStudyGroupExam(
            id: id,
            courseId: courseId,
            courseName: elementInRow('Kurs')?.text.trim() ?? "Unbekannt",
            date: DateTime.parse(dateString),
            type: elementInRow('Art')?.text.trim() ?? "Unbekannt",
            durationLabel: elementInRow('Dauer')?.text.trim(),
            hoursOfDay: elementInRow('Stunden')?.text.trim()));
      }
    }

    List<StudentStudyGroup> studyGroups = [];
    if (courses != null) {
      List<String> courseTableHead = [];
      courses.querySelectorAll('thead tr th').forEach((element) {
        courseTableHead.add(element.text.trim());
      });

      for (final Element courseTableRow
          in courses.querySelectorAll('tbody tr')) {
        final String? id = courseTableRow.attributes['data-id'];
        if (id == null) continue;

        Element? elementInRow(String key) {
          int index = courseTableHead.indexOf(key);
          if (index == -1) return null;
          if (index >= courseTableRow.children.length) return null;
          return courseTableRow.children[index];
        }

        List<StudentStudyGroupTeacher> teachers = [];
        final teacherElement = elementInRow('Lehrkraft');
        if (teacherElement != null) {
          for (final Element teacherButton in teacherElement.children) {
            String teacherName = teacherButton
                .querySelector(
                    'ul.dropdown-menu > li > a > i.fa.fa-user.fa-fw')!
                .parent!
                .text
                .trim();
            List<String> teacherNameSplit = teacherName.split(',');
            teachers.add(
              StudentStudyGroupTeacher(
                firstName: teacherNameSplit.length > 1
                    ? teacherNameSplit[1].trim()
                    : "",
                lastName: teacherNameSplit.isNotEmpty
                    ? teacherNameSplit[0].trim()
                    : "",
                krz: teacherButton
                        .querySelector(
                            'button.btn.btn-primary.dropdown-toggle.btn-md')
                        ?.text
                        .trim() ??
                    "",
                email: teacherButton
                    .querySelector(
                        'ul.dropdown-menu > li > a > i.fa.fa-at.fa-fw')
                    ?.parent
                    ?.text
                    .trim(),
              ),
            );
          }
        }

        String sysId =
            elementInRow('Kursname')!.querySelector('small')!.text.trim();
        elementInRow('Kursname')?.querySelector('small')?.innerHtml = '';
        studyGroups.add(StudentStudyGroup(
          id: id,
          semester: elementInRow('Halbjahr')?.text.trim() ?? "Fehler",
          courseName: elementInRow('Kursname')?.text.trim() ?? "Fehler",
          courseSysId: sysId.substring(1, sysId.length - 1),
          teachers: teachers,
          exams: studyGroupExams.where((exam) => exam.courseId == id).toList(),
        ));
      }
    }

    return StudentStudyGroups(groups: studyGroups, exams: studyGroupExams);
  }
}
