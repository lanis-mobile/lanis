import 'package:flutter/material.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/applets/lessons/student/lessons_student_view.dart';
import 'package:lanis/applets/lessons/teacher/lessons_teacher_view.dart';

import '../../models/account_types.dart';

final lessonsDefinition = AppletDefinition(
  appletPhpUrl: 'meinunterricht.php',
  addDivider: false,
  appletType: AppletType.nested,
  icon: const Icon(Icons.school),
  selectedIcon: const Icon(Icons.school_outlined),
  label: (context) => AppLocalizations.of(context).lessons,
  supportedAccountTypes: [
    AccountType.student,
    AccountType.parent,
    AccountType.teacher,
  ],
  allowOffline: false,
  settingsDefaults: {'showHomework': false},
  refreshInterval: const Duration(minutes: 15),
  bodyBuilder: (context, accountType, openDrawerCb) {
    if (accountType == AccountType.student ||
        accountType == AccountType.parent) {
      return LessonsStudentView(openDrawerCb: openDrawerCb);
    } else if (accountType == AccountType.teacher) {
      return LessonsTeacherView(openDrawerCb: openDrawerCb);
    }
    throw UnimplementedError('This account type is not supported jet');
  },
);
