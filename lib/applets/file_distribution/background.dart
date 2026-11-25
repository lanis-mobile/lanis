import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/file_distribution/routes.dart';
import 'package:lanis/background_service.dart';
import 'package:liblanis/liblanis.dart';

final DateFormat _bgDateFormat = DateFormat('dd.MM.yyyy');

Future<void> fileDistributionBackgroundTask(
  ProviderContainer container,
  AccountType accountType,
  BackgroundTaskToolkit toolkit,
) async {
  final home = await container.read(fileDistributionParserProvider).getHome();
  final unreadItems = home.items.where((e) => e.isUnread);

  for (final item in unreadItems) {
    final firstLine = item.description
        ?.split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');

    final fallbackParts = <String>[
      if (item.files.isNotEmpty) item.files.map((f) => f.name).join(', '),
      if (item.creatorName != null && item.creatorName!.isNotEmpty)
        item.creatorName!,
      if (item.validUntil != null) _bgDateFormat.format(item.validUntil!),
    ];

    final body = (firstLine != null && firstLine.isNotEmpty)
        ? firstLine
        : (fallbackParts.isNotEmpty ? fallbackParts.join(' · ') : item.title);

    await toolkit.sendMessage(
      id: (item.id & 0x7fffffff) % 10000,
      title: item.title,
      message: body,
      avoidDuplicateSending: true,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      redirectUri: fileDistributionItemPath(item.id),
    );
  }
}
