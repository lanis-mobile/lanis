import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/models/account_types.dart';

import '../../core/sph/sph.dart';

Future<void> conversationsBackgroundTask(
    SPH sph, AccountType accountType, BackgroundTaskToolkit toolkit) async {
  final data = await sph.parser.conversationsParser.getHome();
  final unreadMessages = data.where((e) => e.unread).toList();
  for (final unreadMessage in unreadMessages) {
    toolkit.sendMessage(
        id: unreadMessage.id.hashCode % 10000,
        title: unreadMessage.fullName,
        message: unreadMessage.title,
        avoidDuplicateSending: true,
        importance: Importance.high);
  }
}
