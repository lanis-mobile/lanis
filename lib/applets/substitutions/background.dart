import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';

import '../../background_service.dart';
import 'package:lanis/l10n/account_type_ui.dart';

Future<void> substitutionsBackgroundTask(
  ProviderContainer container,
  AccountType accountType,
  BackgroundTaskToolkit tools,
) async {
  final vPlan = await container.read(substitutionsParserProvider).getHome();
  List<Substitution> allSubstitutions = vPlan.allSubstitutions;
  String messageBody = "";

  for (final entry in allSubstitutions) {
    final time =
        "${weekDayGer(entry.tag)} ${entry.stunde.replaceAll(" - ", "/")}";
    final type = entry.art ?? "";
    final subject = entry.fach ?? "";
    final teacher = entry.lehrer ?? "";
    final classInfo = entry.klasse ?? "";

    final entryText = [
      time,
      type,
      subject,
      teacher,
      classInfo,
    ].where((e) => e.isNotEmpty).join(" - ");

    messageBody += "$entryText\n";
  }

  if (messageBody.isEmpty) {
    return;
  }

  await tools.sendMessage(
    title: '${allSubstitutions.length} Einträge im Vertretungsplan',
    message: messageBody,
    id: 0,
    importance: Importance.defaultImportance,
    avoidDuplicateSending: true,
  );
}

String weekDayGer(String dateString) {
  final inputFormat = DateFormat('dd.MM.yyyy');
  final dateTime = inputFormat.parse(dateString);

  final germanFormat = DateFormat('E', 'de');
  return germanFormat.format(dateTime);
}
