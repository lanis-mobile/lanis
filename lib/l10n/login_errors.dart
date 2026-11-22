import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';

String? localizedAccountLoginError(
  AppLocalizations l10n,
  LanisException? exception,
) => switch (exception) {
  ParentAccountWithoutLearnersException() => l10n.loginParentWithoutLearners,
  AccountDisabledException() => l10n.loginAccountDisabled,
  PasswordChangeRequiredException() => l10n.loginPasswordChangeRequired,
  _ => null,
};
