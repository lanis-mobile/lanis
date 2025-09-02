import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:lanis/core/applet_parser.dart';
import 'package:lanis/models/study_groups.dart';

class StudyGroupsStudentParser extends AppletParser<List<StudentStudyGroups>> {
  StudyGroupsStudentParser(super.sph, super.appletDefinition);

  @override
  List<StudentStudyGroups> typeFromJson(String json) {
    return (jsonDecode(json) as List)
        .map((item) => StudentStudyGroups.fromJson(item))
        .toList();
  }

  @override
  Future<List<StudentStudyGroups>> getHome() async {
    Response response = await sph.session.dio
        .get('https://start.schulportal.hessen.de/lerngruppen.php');

    Document document = parse(response.data);

    Element? courses = document.getElementById('LGs');
    Element? exams = document.getElementById('klausuren');

    StudentStudyGroupsData? examData = exams != null ? parseExams(exams) : null;
    StudentStudyGroupsData courseData = parseCourses(courses!);

    List<StudentStudyGroups> studyGroups = [];
    for (int i = 0; i < courseData.data.length; i++) {
      List<String> data = courseData.data[i];

      String courseName = data[1].split('(')[0].trim();
      String teacher = data[2].split('(')[0].trim();
      String teacherKuerzel = data[2].split('(')[1].split(')')[0].trim();
      String? picture = data[4].isNotEmpty ? data[4] : null;
      String? fileName = data[5].isNotEmpty ? data[5] : null;
      Uri? email = data[6].isNotEmpty ? Uri.parse(data[6]) : null;

      // Filters mapped by courseName
      List<List<String>>? examsInCourse = examData?.data
          .where((element) => element[1].contains(courseName))
          .toList();

      studyGroups.add(StudentStudyGroups(
        halfYear: data[0],
        courseName: courseName,
        teacher: teacher,
        teacherKuerzel: teacherKuerzel,
        picture: picture != null ? (name: fileName!, url: picture) : null,
        email: email,
        exams: examsInCourse
            ?.map((e) => StudentExam(
                  date: DateTime.parse(
                      e[0].split(', ')[1].split('.').reversed.join('-')),
                  time: e[3],
                  type: e[2],
                  duration: e[4],
                ))
            .toList(),
      ));
    }

    return studyGroups;
  }

  StudentStudyGroupsData parseExams(Element exams) {
    List<String> examHeaders = [];
    Element? examTable = exams.querySelector('table');
    examTable!.querySelectorAll('thead tr th').forEach((element) {
      examHeaders.add(element.text.trim());
    });

    // Exams parse tbody
    List<List<String>> examData = [];
    RegExp dateRegex = RegExp(r'.{2}, \d{2}\.\d{2}\.\d{4}');
    examTable.querySelectorAll('tbody tr').forEach((element) {
      List<String> examRow = [];
      // Check if first element contains a date
      if (element.querySelector('td')!.text.trim().contains(dateRegex)) {
        element.querySelectorAll('td').asMap().forEach((index, element) {
          if (index == 0) {
            RegExpMatch? match = dateRegex.firstMatch(element.text.trim());
            // Match must be true, because of above if
            examRow.add(match!.group(0)!);
          } else {
            examRow.add(element.text.trim());
          }
        });
        examData.add(examRow);
      }
    });

    return StudentStudyGroupsData(examHeaders, examData);
  }

  StudentStudyGroupsData parseCourses(Element courses) {
    List<String> courseHeaders = [];
    courses.querySelectorAll('thead tr th').forEach((element) {
      courseHeaders.add(element.text.trim());
    });

    // Courses parse tbody
    List<List<String>> courseData = [];

    courses.querySelectorAll('tbody tr').forEach((row) {
      List<String> courseRow = [];

      courseRow.add(row.children[0].text.trim());
      courseRow.add(row.children[1].text.trim());

      final teacherElement = row.children[2].getElementsByTagName('div').first;
      log(teacherElement.text);
      final linkElement = teacherElement.querySelector("a");
      String? email;

      if (linkElement != null) {
        final emailTextElement = teacherElement.querySelector("a small");

        if (emailTextElement != null) {
          email = "mailto:${emailTextElement.text.trim()}";
          emailTextElement.remove();
        }

        courseRow.add(
            "${linkElement.text.trim()}(${teacherElement.text.trim().split(' ')[0]})");
      } else {
        courseRow.add(
            "${teacherElement.text.trim().split(' ')[1].trim()}(${teacherElement.text.trim().split(' ')[0]})");
      }

      courseRow.add(row.children.length > 3
          ? row.children[3].innerHtml
              .split('<br>')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .join('|')
          : "");

      final imageElement = row.children[2].querySelector("img");
      if (imageElement != null) {
        courseRow.add(
            "https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userFoto&b=show&&t=l&p=${imageElement.attributes["src"]!.split("-")[2]}");
        courseRow.add(imageElement.attributes["src"]!);
      } else {
        courseRow.addAll(["", ""]);
      }

      courseRow.add(email ?? "");

      courseData.add(courseRow);
    });

    return StudentStudyGroupsData(courseHeaders, courseData);
  }
}
