import 'package:flutter/material.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/study_groups/routes.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/utils/deep_link.dart';

final studyGroupsDefinition = AppletDefinition(
  appletPhpUrl: 'lerngruppen.php',
  pathSegment: 'study-groups',
  deepLinkScope: DeepLinkScope.accountTyped,
  buildRoutes: buildStudyGroupsRoutes,
  addDivider: false,
  appletType: AppletType.navigation,
  icon: const Icon(Icons.groups),
  selectedIcon: const Icon(Icons.groups_outlined),
  label: (context) => AppLocalizations.of(context).studyGroups,
  supportedAccountTypes: [AccountType.student],
  allowOffline: false,
  settingsDefaults: {'showExams': 'true'},
  refreshInterval: const Duration(minutes: 15),
  bodyBuilder: (context, accountType, openDrawerCb) {
    // Home route uses [StudyGroupsModePage] from routes.dart.
    return const StudyGroupsModePage(showExams: false);
  },
);
