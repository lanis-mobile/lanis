import 'package:material_ui/material_ui.dart';
import 'package:liblanis/liblanis.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../generated/l10n.dart';
import '../../utils/safe_launch.dart';

/// Validate the login without writing an account or selecting it in the app.
Future<void> verifyAccountLogin(
  ClearTextAccount account,
  LanisConfig config,
  ConnectionChecker connectionChecker,
) async {
  final session = LanisSession(
    account: account,
    config: config,
    connectionChecker: connectionChecker,
  );
  try {
    await session.prepareDio();
    await session.authenticate();
  } finally {
    await session.dispose();
  }
}

Future<void> openPortalPasswordChange(
  BuildContext context,
  ClearTextAccount account,
  LanisConfig config,
) async {
  final Uri uri;
  try {
    uri = Uri.parse(await LanisSession.getLoginURL(account, config));
    if (uri.origin != 'https://start.schulportal.hessen.de' ||
        uri.path != '/schulportallogin.php') {
      throw const FormatException('Unexpected Schulportal login link');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).couldNotOpenUrl)),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await safeLaunchUrl(
    uri,
    context: context,
    sensitive: true,
    mode: LaunchMode.externalApplication,
  );
}
