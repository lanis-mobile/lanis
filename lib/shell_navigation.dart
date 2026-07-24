import 'package:lanis/applets/definitions.dart';

/// Path of the settings shell branch (kept beside the tablet rail).
const settingsShellPath = '/settings';

/// Branch index for [def] inside the home [StatefulShellRoute].
///
/// Order: [AppDefinitions.homeApplets], then [AppDefinitions.navigationApplets],
/// then settings.
int shellBranchIndexForApplet(AppletDefinition def) {
  final home = AppDefinitions.homeApplets;
  final nested = home.indexWhere((a) => a.routePath == def.routePath);
  if (nested >= 0) return nested;
  final nav = AppDefinitions.navigationApplets.indexWhere(
    (a) => a.routePath == def.routePath,
  );
  if (nav >= 0) return home.length + nav;
  throw StateError('Unknown applet route ${def.routePath}');
}

int get settingsShellBranchIndex =>
    AppDefinitions.homeApplets.length + AppDefinitions.navigationApplets.length;
