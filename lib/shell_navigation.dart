import 'package:lanis/applets/definitions.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/utils/deep_link.dart';

/// Path of the settings shell branch (kept beside the tablet rail).
const settingsShellPath = SettingsDeepLinks.home;

/// Branch index for [def] inside the home [StatefulShellRoute].
///
/// Order: [AppDefinitions.homeApplets], then [AppDefinitions.navigationApplets],
/// then settings.
int shellBranchIndexForApplet(AppletDefinition def) {
  final home = AppDefinitions.homeApplets;
  final nested = home.indexWhere((a) => a.pathSegment == def.pathSegment);
  if (nested >= 0) return nested;
  final nav = AppDefinitions.navigationApplets.indexWhere(
    (a) => a.pathSegment == def.pathSegment,
  );
  if (nav >= 0) return home.length + nav;
  throw StateError('Unknown applet segment ${def.pathSegment}');
}

int get settingsShellBranchIndex =>
    AppDefinitions.homeApplets.length + AppDefinitions.navigationApplets.length;

/// Home path for [def] using the current session account type when needed.
String appletHomePath(AppletDefinition def, AccountType accountType) {
  if (def.deepLinkScope == DeepLinkScope.common) {
    return def.homePath();
  }
  return def.homePath(accountType);
}
