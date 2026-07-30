import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/calendar/definition.dart';
import 'package:lanis/applets/conversations/definition.dart';
import 'package:lanis/applets/data_storage/definition.dart';
import 'package:lanis/applets/external_definitions.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/applets/study_groups/definition.dart';
import 'package:lanis/applets/substitutions/definition.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/utils/deep_link.dart';

import '../background_service.dart';

typedef StringBuildContextCallback = String Function(BuildContext context);
typedef WidgetBuildBody =
    Widget Function(
      BuildContext context,
      AccountType accountType,
      Function? openDrawerCb,
    );
typedef BackgroundTaskFunction =
    Future<void> Function(
      ProviderContainer container,
      AccountType accountType,
      BackgroundTaskToolkit toolkit,
    );

enum AppletType { nested, navigation }

/// Context passed into each applet's [AppletDefinition.buildRoutes].
class AppletRouteContext {
  final GlobalKey<NavigatorState> rootNavigatorKey;
  final Widget Function(AppletDefinition def) homeBody;

  const AppletRouteContext({
    required this.rootNavigatorKey,
    required this.homeBody,
  });
}

typedef AppletRoutesBuilder =
    List<RouteBase> Function(AppletRouteContext context);

class AppletDefinition {
  final String appletPhpUrl;

  /// Last path segment, e.g. `substitutions` or `lessons`.
  final String pathSegment;

  /// Whether routes live under `/common/…` or `/student|teacher|parent/…`.
  final DeepLinkScope deepLinkScope;

  /// Builds go_router routes for this applet (owned by the applet package).
  final AppletRoutesBuilder buildRoutes;

  final Icon icon;
  final Icon selectedIcon;
  final AppletType appletType;
  final bool addDivider;
  final StringBuildContextCallback label;
  final List<AccountType> supportedAccountTypes;
  final bool allowOffline;
  final Duration refreshInterval;
  final Map<String, dynamic> settingsDefaults;

  /// When true, this navigation applet is offered on the tablet [NavigationRail].
  final bool showInNavigationRail;
  WidgetBuildBody? bodyBuilder;
  BackgroundTaskFunction? notificationTask;

  bool get enableBottomNavigation => appletType == AppletType.nested;

  AppletDefinition({
    required this.appletPhpUrl,
    required this.pathSegment,
    required this.deepLinkScope,
    required this.buildRoutes,
    required this.icon,
    required this.selectedIcon,
    required this.appletType,
    required this.addDivider,
    required this.label,
    required this.supportedAccountTypes,
    required this.refreshInterval,
    required this.settingsDefaults,
    this.notificationTask,
    this.bodyBuilder,
    this.allowOffline = false,
    this.showInNavigationRail = false,
  });

  String prefixFor(AccountType accountType) =>
      DeepLinkPrefixes.forScope(deepLinkScope, accountType);

  /// Base path without trailing page, e.g. `/common/substitutions`.
  String basePath([AccountType? accountType]) {
    final prefix = deepLinkScope == DeepLinkScope.common
        ? DeepLinkPrefixes.common
        : (accountType ?? supportedAccountTypes.first).name;
    return '/$prefix/$pathSegment';
  }

  /// Home location, e.g. `/common/substitutions/home`.
  String homePath([AccountType? accountType]) => '${basePath(accountType)}/home';

  /// Legacy-style getter used where account type is not available yet.
  String get routePath => homePath(
    deepLinkScope == DeepLinkScope.common
        ? null
        : supportedAccountTypes.first,
  );

  bool matchesLocation(String loc) {
    if (deepLinkScope == DeepLinkScope.common) {
      final base = basePath();
      return loc == base || loc.startsWith('$base/');
    }
    for (final type in supportedAccountTypes) {
      final base = basePath(type);
      if (loc == base || loc.startsWith('$base/')) return true;
    }
    return false;
  }
}

class ExternalDefinition {
  final String id;
  final StringBuildContextCallback label;
  final Icon icon;
  final Function(BuildContext?)? action;

  /// When true, this external shortcut is offered on the tablet [NavigationRail].
  final bool showInNavigationRail;

  ExternalDefinition({
    required this.id,
    required this.label,
    this.action,
    this.icon = const Icon(Icons.open_in_new),
    this.showInNavigationRail = false,
  });
}

class AppDefinitions {
  static List<AppletDefinition> applets = [
    substitutionDefinition,
    calendarDefinition,
    timeTableDefinition,
    conversationsDefinition,
    lessonsDefinition,
    dataStorageDefinition,
    studyGroupsDefinition,
  ];

  /// Bottom-nav / [StatefulShellRoute] branches (order = branch index).
  static List<AppletDefinition> get homeApplets =>
      applets.where((a) => a.appletType == AppletType.nested).toList();

  /// Full-screen applets hosted as shell branches so tablet [NavigationRail]
  /// stays visible.
  static List<AppletDefinition> get navigationApplets =>
      applets.where((a) => a.appletType == AppletType.navigation).toList();

  static List<ExternalDefinition> external = [
    openLanisDefinition,
    openMoodleDefinition,
  ];

  static bool isAppletSupported(AccountType accountType, String phpIdentifier) {
    return applets.any(
      (element) =>
          element.supportedAccountTypes.contains(accountType) &&
          element.appletPhpUrl == phpIdentifier,
    );
  }

  static AppletDefinition getByPhpIdentifier(String phpIdentifier) {
    return applets.firstWhere(
      (element) => element.appletPhpUrl == phpIdentifier,
    );
  }

  static int getIndexByPhpIdentifier(String phpIdentifier) {
    return applets.indexWhere(
      (element) => element.appletPhpUrl == phpIdentifier,
    );
  }

  static AppletDefinition? findMatchingLocation(String loc) {
    for (final def in applets) {
      if (def.matchesLocation(loc)) return def;
    }
    return null;
  }
}
