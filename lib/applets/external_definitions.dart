import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/view/moodle.dart';
import 'package:liblanis/liblanis.dart';
import 'package:url_launcher/url_launcher.dart';

final openLanisDefinition = ExternalDefinition(
  id: 'openLanis',
  label: (context) => AppLocalizations.of(context).openLanisInBrowser,
  // Flip to true to pin this shortcut on the tablet navigation rail.
  showInNavigationRail: false,
  action: (context) {
    if (context == null) return;
    final container = ProviderScope.containerOf(context);
    final account = container.read(activeAccountProvider);
    if (account == null) return;
    final config = container.read(lanisConfigProvider);
    LanisSession.getLoginURL(account, config).then((response) {
      launchUrl(Uri.parse(response));
    }).catchError((Object error, StackTrace stackTrace) {
      debugPrint('Failed to open Lanis login URL: $error');
    });
  },
);

final openMoodleDefinition = ExternalDefinition(
  id: 'openMoodle',
  label: (context) => AppLocalizations.of(context).openMoodle,
  // Flip to true to pin this shortcut on the tablet navigation rail.
  showInNavigationRail: false,
  action: (context) {
    if (context == null) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MoodleWebView()),
    );
  },
);
