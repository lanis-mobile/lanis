import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart' show AccountType, AccountTypeX;
import 'package:lanis/generated/l10n.dart';

export 'package:liblanis/liblanis.dart' show AccountType;

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

  static AccountType fromString(String type) => AccountTypeX.fromString(type);
}
