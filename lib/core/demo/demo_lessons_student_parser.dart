import 'package:lanis/applets/lessons/student/parser.dart';
import 'package:lanis/core/demo/demo_fetch_mixin.dart';
import 'package:lanis/models/lessons.dart';

class DemoLessonsStudentParser extends LessonsStudentParser with DemoFetchMixin<Lessons> {
  DemoLessonsStudentParser(super.sph, super.appletDefinition);

  @override
  Future<Lessons> getHome() async {
    final now = DateTime.now();
    return [
      Lesson(
        courseID: 'demo-ma',
        name: 'Mathematik (10a)',
        teachers: [LessonTeacher(teacher: 'Herr Müller', teacherKuerzel: 'MÜL')],
        courseURL: Uri.parse('https://start.schulportal.hessen.de/meinunterricht.php?id=demo-ma'),
        attendances: {'anwesend': '22', 'entschuldigt': '1', 'unentschuldigt': '0', 'verspätet': '2'},
        currentEntry: CurrentEntry(
          entryID: 'demo-ma-1',
          topicTitle: 'Quadratische Gleichungen',
          description: 'Lösungsverfahren: PQ-Formel und quadratische Ergänzung',
          topicDate: now.subtract(const Duration(days: 1)),
          schoolHours: '3',
          presence: 'anwesend',
          homework: Homework(description: 'Aufgaben S. 87 Nr. 3–6', homeWorkDone: false),
          files: [],
          uploads: [],
        ),
      ),
      Lesson(
        courseID: 'demo-de',
        name: 'Deutsch (10a)',
        teachers: [LessonTeacher(teacher: 'Frau Koch', teacherKuerzel: 'KOC')],
        courseURL: Uri.parse('https://start.schulportal.hessen.de/meinunterricht.php?id=demo-de'),
        attendances: {'anwesend': '23', 'entschuldigt': '0', 'unentschuldigt': '0', 'verspätet': '0'},
        currentEntry: CurrentEntry(
          entryID: 'demo-de-1',
          topicTitle: 'Erörterung schreiben',
          description: 'Aufbau und Argumentation einer Erörterung',
          topicDate: now.subtract(const Duration(days: 2)),
          schoolHours: '1',
          presence: 'anwesend',
          homework: Homework(description: 'Einleitung fertigschreiben', homeWorkDone: true),
          files: [],
          uploads: [],
        ),
      ),
      Lesson(
        courseID: 'demo-en',
        name: 'Englisch (10a)',
        teachers: [LessonTeacher(teacher: 'Frau Weber', teacherKuerzel: 'WEB')],
        courseURL: Uri.parse('https://start.schulportal.hessen.de/meinunterricht.php?id=demo-en'),
        attendances: {'anwesend': '21', 'entschuldigt': '2', 'unentschuldigt': '0', 'verspätet': '1'},
        currentEntry: CurrentEntry(
          entryID: 'demo-en-1',
          topicTitle: 'Present Perfect vs. Simple Past',
          description: 'Unterschiede und Anwendungsbeispiele',
          topicDate: now,
          schoolHours: '5',
          presence: 'anwesend',
          homework: null,
          files: [],
          uploads: [],
        ),
      ),
      Lesson(
        courseID: 'demo-bi',
        name: 'Biologie (10a)',
        teachers: [LessonTeacher(teacher: 'Herr Fischer', teacherKuerzel: 'FIS')],
        courseURL: Uri.parse('https://start.schulportal.hessen.de/meinunterricht.php?id=demo-bi'),
        attendances: {'anwesend': '23', 'entschuldigt': '0', 'unentschuldigt': '0', 'verspätet': '0'},
        currentEntry: CurrentEntry(
          entryID: 'demo-bi-1',
          topicTitle: 'Zellteilung: Mitose',
          description: 'Phasen der Mitose und ihre Bedeutung',
          topicDate: now.subtract(const Duration(days: 3)),
          schoolHours: '4',
          presence: 'anwesend',
          homework: Homework(description: 'Lernzettel zu den Mitose-Phasen', homeWorkDone: false),
          files: [],
          uploads: [],
        ),
      ),
    ];
  }
}
