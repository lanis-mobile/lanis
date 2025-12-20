import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/models/account_types.dart';
import 'package:lanis/models/lessons.dart';

import '../../../core/sph/sph.dart';

Future<void> lessonsStudentBackgroundTask(
  SPH sph,
  AccountType accountType,
  BackgroundTaskToolkit toolkit,
) async {
  if (accountType != AccountType.student) return;

  final List<Lesson> lessons = await sph.parser.lessonsStudentParser.getHome();

  for (final lesson in lessons) {
    if (lesson.currentEntry?.homework == null) continue;
    if (lesson.currentEntry!.homework!.homeWorkDone) continue;

    toolkit.sendMessage(
      id: lesson.courseID.hashCode % 10000,
      title: "Neue Hausaufgabe in Kurs ${lesson.name}",
      message:
          "${lesson.currentEntry!.topicTitle != null ? "${lesson.currentEntry!.topicTitle}\n" : ''}${lesson.currentEntry!.homework!.description}",
      avoidDuplicateSending: true,
      importance: Importance.defaultImportance,
    );
  }
}
