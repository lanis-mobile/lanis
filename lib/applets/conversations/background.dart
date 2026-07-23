import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:liblanis/liblanis.dart';

Future<void> conversationsBackgroundTask(
  ProviderContainer container,
  AccountType accountType,
  BackgroundTaskToolkit toolkit,
) async {
  final data = await container.read(conversationsParserProvider).getHome();
  final unreadMessages = data.where((e) => e.unread).toList();
  for (final unreadMessage in unreadMessages) {
    await toolkit.sendMessage(
      id: (unreadMessage.id.hashCode & 0x7fffffff) % 10000,
      title: unreadMessage.fullName,
      message: unreadMessage.title,
      avoidDuplicateSending: true,
      importance: Importance.high,
    );
  }
}
