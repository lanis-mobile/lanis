import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/background_service.dart';
import 'package:liblanis/liblanis.dart';

Future<void> lessonsStudentBackgroundTask(
  ProviderContainer container,
  AccountType accountType,
  BackgroundTaskToolkit toolkit,
) async {
  if (accountType != AccountType.student) return;

  final Lessons lessons =
      await container.read(lessonsStudentParserProvider).getHome();

  for (final lesson in lessons) {
    if (lesson.currentEntry?.homework == null) continue;
    if (lesson.currentEntry!.homework!.homeWorkDone) continue;

    final semester = lesson.courseURL.queryParameters['halb'];
    final semesterQuery = semester == null
        ? ''
        : '&semester=${Uri.encodeComponent(semester)}';
    final redirectUri = lesson.courseID.isNotEmpty
        ? '/student/lessons/course/${Uri.encodeComponent(lesson.courseID)}?title=${Uri.encodeComponent(lesson.name)}$semesterQuery'
        : lessonsDefinition.homePath(AccountType.student);

    await toolkit.sendMessage(
      id: (lesson.courseID.hashCode & 0x7fffffff) % 10000,
      title: "Neue Hausaufgabe in Kurs ${lesson.name}",
      message:
          "${lesson.currentEntry!.topicTitle != null ? "${lesson.currentEntry!.topicTitle}\n" : ''}${lesson.currentEntry!.homework!.description}",
      avoidDuplicateSending: true,
      importance: Importance.defaultImportance,
      redirectUri: redirectUri,
    );
  }
}
