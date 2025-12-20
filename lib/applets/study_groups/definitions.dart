import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/study_groups/student/student_study_groups_view.dart';

import '../../models/account_types.dart';

final studyGroupsDefinition = AppletDefinition(
  appletPhpUrl: 'lerngruppen.php',
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
    return StudentStudyGroupsView();
  },
);
