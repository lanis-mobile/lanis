import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/models/account_types.dart';
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
