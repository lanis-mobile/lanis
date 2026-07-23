import 'package:flutter/material.dart';
import 'package:lanis/applets/calendar/calendar_view.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/generated/l10n.dart';

import 'package:lanis/l10n/account_type_ui.dart';

final calendarDefinition = AppletDefinition(
  appletPhpUrl: 'kalender.php',
  routePath: '/home/calendar',
  addDivider: false,
  appletType: AppletType.nested,
  icon: const Icon(Icons.calendar_today),
  selectedIcon: const Icon(Icons.calendar_today_outlined),
  label: (context) => AppLocalizations.of(context).calendar,
  supportedAccountTypes: [
    AccountType.student,
    AccountType.teacher,
    AccountType.parent,
  ],
  allowOffline: false,
  settingsDefaults: {},
  refreshInterval: const Duration(hours: 1),
  bodyBuilder: (context, accountType, openDrawerCb) {
    return CalendarView(openDrawerCb: openDrawerCb);
  },
);
