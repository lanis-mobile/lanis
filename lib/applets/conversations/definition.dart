import 'package:flutter/material.dart';
import 'package:lanis/applets/conversations/view/conversations_view.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/generated/l10n.dart';

import '../../models/account_types.dart';
import 'background.dart';

final conversationsDefinition = AppletDefinition(
  appletPhpUrl: 'nachrichten.php',
  addDivider: false,
  appletType: AppletType.nested,
  icon: const Icon(Icons.forum),
  selectedIcon: const Icon(Icons.forum_outlined),
  label: (context) => AppLocalizations.of(context).messages,
  supportedAccountTypes: [
    AccountType.student,
    AccountType.teacher,
    AccountType.parent,
  ],
  allowOffline: false,
  settingsDefaults: {},
  notificationTask: conversationsBackgroundTask,
  refreshInterval: const Duration(minutes: 2),
  bodyBuilder: (context, accountType, openDrawerCb) {
    return ConversationsView(openDrawerCb: openDrawerCb);
  },
);
