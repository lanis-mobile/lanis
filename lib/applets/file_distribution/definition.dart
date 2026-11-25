import 'package:material_ui/material_ui.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/file_distribution/file_distribution_view.dart';
import 'package:lanis/applets/file_distribution/routes.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:liblanis/liblanis.dart';

final fileDistributionDefinition = AppletDefinition(
  appletPhpUrl: Applets.fileDistribution.appletPhpUrl,
  pathSegment: 'file-distribution',
  deepLinkScope: DeepLinkScope.common,
  buildRoutes: buildFileDistributionRoutes,
  addDivider: false,
  appletType: AppletType.navigation,
  icon: const Icon(Icons.move_to_inbox),
  selectedIcon: const Icon(Icons.move_to_inbox_outlined),
  label: (context) => AppLocalizations.of(context).fileDistribution,
  supportedAccountTypes: Applets.fileDistribution.supportedAccountTypes,
  allowOffline: true,
  showInNavigationRail: true,
  settingsDefaults: {},
  refreshInterval: Applets.fileDistribution.refreshInterval,
  bodyBuilder: (context, accountType, openDrawerCb) {
    return FileDistributionView(
      openDrawerCb: openDrawerCb,
      accountType: accountType,
    );
  },
);
