import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/applets/data_storage/data_storage_root_view.dart';
import 'package:lanis/applets/definitions.dart';

import 'package:lanis/l10n/account_type_ui.dart';

final dataStorageDefinition = AppletDefinition(
  appletPhpUrl: 'dateispeicher.php',
  routePath: '/storage',
  addDivider: true,
  appletType: AppletType.navigation,
  icon: const Icon(Icons.folder_copy),
  selectedIcon: const Icon(Icons.folder_copy_outlined),
  label: (context) => AppLocalizations.of(context).storage,
  supportedAccountTypes: [
    AccountType.student,
    AccountType.teacher,
    AccountType.parent,
  ],
  allowOffline: false,
  showInNavigationRail: true,
  settingsDefaults: {},
  refreshInterval: const Duration(minutes: 5),
  bodyBuilder: (context, accountType, openDrawerCb) {
    return DataStorageRootView(openDrawerCb: openDrawerCb);
  },
);
