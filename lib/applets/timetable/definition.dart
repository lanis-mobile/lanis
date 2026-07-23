import 'package:flutter/material.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/timetable/student/student_timetable_better_view.dart';
import 'package:lanis/generated/l10n.dart';

import '../../models/account_types.dart';

final timeTableDefinition = AppletDefinition(
  appletPhpUrl: 'stundenplan.php',
  icon: Icon(Icons.timelapse),
  selectedIcon: Icon(Icons.timelapse_outlined),
  appletType: AppletType.nested,
  addDivider: false,
  label: (context) => AppLocalizations.of(context).timeTable,
  supportedAccountTypes: [AccountType.student],
  refreshInterval: Duration(hours: 1),
  allowOffline: true,
  settingsDefaults: {
    'student-selected-type': 'TimeTableType.own',
    'current-timetable-view': 'CalendarView.workWeek',
    'student-selected-week': false,
    'hidden-lessons': <dynamic>[],
    'custom-lessons': <dynamic>[],
    'lesson-colors': <String, dynamic>{},
  },
  bodyBuilder: (context, accountType, openDrawerCb) {
    if (accountType == AccountType.student) {
      return StudentTimetableBetterView(openDrawerCb: openDrawerCb);
    } else {
      return Placeholder();
    }
  },
);
