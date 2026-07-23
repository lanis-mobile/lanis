import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/substitutions/substitutions_view.dart';

import 'package:lanis/l10n/account_type_ui.dart';
import 'background.dart';

final substitutionDefinition = AppletDefinition(
  appletPhpUrl: 'vertretungsplan.php',
  routePath: '/home/substitutions',
  icon: Icon(Icons.people),
  selectedIcon: Icon(Icons.people_outline),
  appletType: AppletType.nested,
  addDivider: false,
  allowOffline: true,
  label: (context) => AppLocalizations.of(context).substitutions,
  supportedAccountTypes: [
    AccountType.student,
    AccountType.teacher,
    AccountType.parent,
  ],
  refreshInterval: Duration(minutes: 10),
  settingsDefaults: {},
  notificationTask: substitutionsBackgroundTask,
  bodyBuilder: (context, accountType, openDrawerCb) {
    return SubstitutionsView(openDrawerCb: openDrawerCb);
  },
);
