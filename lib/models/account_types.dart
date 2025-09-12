import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

enum AccountType {
  student,
  teacher,
  parent,
}

extension AccountTypeExtension on AccountType {
  String readableName(BuildContext context) {
    switch (this) {
      case AccountType.student:
        return AppLocalizations.of(context).student;
      case AccountType.teacher:
        return AppLocalizations.of(context).teacher;
      case AccountType.parent:
        return AppLocalizations.of(context).parent;
    }
  }

  static AccountType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'student':
        return AccountType.student;
      case 'teacher':
        return AccountType.teacher;
      case 'parent':
        return AccountType.parent;
      default:
        return AccountType.student; // Default to student if unknown
    }
  }
}
