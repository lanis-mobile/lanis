import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/shell_navigation.dart';
import 'package:lanis/utils/cached_network_image.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/utils/whats_new.dart';
import 'package:url_launcher/url_launcher.dart';

/// Nested home applet paths (order matches bottom-nav / shell branches).
List<String> get homeAppletPaths =>
    AppDefinitions.homeApplets.map((a) => a.routePath).toList();

List<String> get homeAppletPhpUrls =>
    AppDefinitions.homeApplets.map((a) => a.appletPhpUrl).toList();

/// First home tab path supported by the current session's feature set.
String firstSupportedHomePath(WidgetRef ref) {
  final supported = ref.read(supportedAppletPhpUrlsProvider);
  for (final def in AppDefinitions.homeApplets) {
    if (supported.contains(def.appletPhpUrl)) return def.routePath;
  }
  return AppDefinitions.homeApplets.first.routePath;
}

/// Same as [firstSupportedHomePath] for non-widget [Ref] (e.g. go_router).
String firstSupportedHomePathFromRef(Ref ref) {
  final supported = ref.read(supportedAppletPhpUrlsProvider);
  for (final def in AppDefinitions.homeApplets) {
    if (supported.contains(def.appletPhpUrl)) return def.routePath;
  }
  return AppDefinitions.homeApplets.first.routePath;
}

class HomePage extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const HomePage({super.key, required this.navigationShell});

  @override
  ConsumerState<HomePage> createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  final GlobalKey<ScaffoldState> _drawerKey = GlobalKey();

  /// Last bottom-nav (home) branch — restored on system back from storage/settings.
  int _lastHomeBranchIndex = 0;

  @override
  void initState() {
    super.initState();
    final current = widget.navigationShell.currentIndex;
    if (current < AppDefinitions.homeApplets.length) {
      _lastHomeBranchIndex = current;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showUpdateInfoIfRequired(context);
    });
  }

  LanisSession? get _session => ref.read(sessionProvider).asData?.value;

  ClearTextAccount? get _account => ref.read(activeAccountProvider);

  bool _supports(String phpUrl) =>
      ref.read(supportedAppletPhpUrlsProvider).contains(phpUrl);

  bool get _onHomeBranch =>
      widget.navigationShell.currentIndex < AppDefinitions.homeApplets.length;

  Future<void> _openLanisInBrowser() async {
    final account = _account;
    final config = ref.read(lanisConfigProvider);
    if (account == null) return;
    try {
      final url = await LanisSession.getLoginURL(account, config);
      await launchUrl(Uri.parse(url));
    } on LanisException catch (ex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ex.cause), duration: const Duration(seconds: 1)),
      );
    }
  }

  Future<void> _logout() async {
    final account = _account;
    if (account == null) {
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go('/welcome');
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .removeAccountAndContinue(account.localId);
    final phase = ref.read(authControllerProvider).phase;
    if (!mounted) return;
    if (phase == AuthPhase.authenticated) {
      context.go(firstSupportedHomePath(ref));
    } else {
      context.go('/welcome');
    }
  }

  void _goBranch(int index) {
    if (index < AppDefinitions.homeApplets.length) {
      _lastHomeBranchIndex = index;
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _returnToLastHomeBranch() {
    final dest = _supportedHomeDestinations();
    final fallback = dest.indexes.isEmpty ? 0 : dest.indexes.first;
    final target = dest.indexes.contains(_lastHomeBranchIndex)
        ? _lastHomeBranchIndex
        : fallback;
    _goBranch(target);
  }

  Widget noAppsSupported() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lanis-Mobile'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _drawerKey.currentState!.openDrawer(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.disabled_by_default_outlined, size: 150),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(AppLocalizations.of(context).noSupportOpenInBrowser),
            ),
            ElevatedButton(
              onPressed: _openLanisInBrowser,
              child: Text(AppLocalizations.of(context).openLanisInBrowser),
            ),
          ],
        ),
      ),
    );
  }

  /// Supported home-tab destinations shared by bottom bar and rail.
  ({List<int> indexes, List<AppletDefinition> defs}) _supportedHomeDestinations() {
    final nestedDefs = AppDefinitions.homeApplets;
    final indexes = <int>[];
    final defs = <AppletDefinition>[];
    for (var i = 0; i < nestedDefs.length; i++) {
      if (_supports(nestedDefs[i].appletPhpUrl)) {
        indexes.add(i);
        defs.add(nestedDefs[i]);
      }
    }
    return (indexes: indexes, defs: defs);
  }

  /// Drawer rows that participate in [NavigationDrawer.selectedIndex].
  List<({
    String label,
    Icon icon,
    Icon selectedIcon,
    bool enabled,
    int? branchIndex,
    VoidCallback onTap,
  })> _drawerDestinations(BuildContext context) {
    final items = <({
      String label,
      Icon icon,
      Icon selectedIcon,
      bool enabled,
      int? branchIndex,
      VoidCallback onTap,
    })>[];

    for (final def in AppDefinitions.homeApplets) {
      items.add((
        label: def.label(context),
        icon: def.icon,
        selectedIcon: def.selectedIcon,
        enabled: _supports(def.appletPhpUrl),
        branchIndex: shellBranchIndexForApplet(def),
        onTap: () => _goBranch(shellBranchIndexForApplet(def)),
      ));
    }

    for (final def in AppDefinitions.navigationApplets) {
      if (!_supports(def.appletPhpUrl)) continue;
      items.add((
        label: def.label(context),
        icon: def.icon,
        selectedIcon: def.selectedIcon,
        enabled: true,
        branchIndex: shellBranchIndexForApplet(def),
        onTap: () => _goBranch(shellBranchIndexForApplet(def)),
      ));
    }

    items.add((
      label: AppLocalizations.of(context).openMoodle,
      icon: const Icon(Icons.open_in_new),
      selectedIcon: const Icon(Icons.open_in_new),
      enabled: true,
      branchIndex: null,
      onTap: () => context.push('/moodle'),
    ));
    items.add((
      label: AppLocalizations.of(context).openLanisInBrowser,
      icon: const Icon(Icons.open_in_new),
      selectedIcon: const Icon(Icons.open_in_new),
      enabled: true,
      branchIndex: null,
      onTap: _openLanisInBrowser,
    ));
    items.add((
      label: AppLocalizations.of(context).settings,
      icon: const Icon(Icons.settings),
      selectedIcon: const Icon(Icons.settings),
      enabled: true,
      branchIndex: settingsShellBranchIndex,
      onTap: () => _goBranch(settingsShellBranchIndex),
    ));
    items.add((
      label: AppLocalizations.of(context).logout,
      icon: const Icon(Icons.logout),
      selectedIcon: const Icon(Icons.logout),
      enabled: true,
      branchIndex: null,
      onTap: _logout,
    ));

    return items;
  }

  NavigationDrawer navDrawer(BuildContext context) {
    final account = _account;
    final session = _session;
    final homeCount = AppDefinitions.homeApplets.length;
    final destinations = _drawerDestinations(context);

    final Color imageColor = Theme.of(
      context,
    ).colorScheme.inversePrimary.withValues(alpha: 0.5);
    final Color textColor = imageColor.computeLuminance() < 0.5
        ? Colors.white
        : Colors.black;

    final currentBranch = widget.navigationShell.currentIndex;
    final selectedIndex = destinations.indexWhere(
      (d) => d.branchIndex == currentBranch,
    );

    return NavigationDrawer(
      selectedIndex: selectedIndex < 0 ? null : selectedIndex,
      onDestinationSelected: (int index) {
        Navigator.pop(context);
        if (index >= 0 && index < destinations.length) {
          destinations[index].onTap();
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Stack(
            children: [
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  ClipRRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          imageColor,
                          BlendMode.srcOver,
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 8,
                          child: CachedNetworkImage(
                            imageUrl: Uri.parse(
                              'https://startcache.schulportal.hessen.de/exporteur.php?a=schoolbg&i=${account?.schoolID ?? 0}&s=xs',
                            ),
                            placeholder: const Image(
                              image: AssetImage('assets/icon.png'),
                              fit: BoxFit.cover,
                            ),
                            builder: (context, imageProvider) {
                              return Image(
                                fit: BoxFit.cover,
                                image: imageProvider,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${session?.userData['nachname'] ?? ''}, ${session?.userData['vorname'] ?? ''}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                        ),
                        Text(
                          account?.schoolName ?? '',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: textColor),
                        ),
                        if (account?.accountType != null)
                          Text(
                            account!.accountType!.readableName(context),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(color: textColor),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 2),
                  child: IconButton(
                    onPressed: () => context.push('/accounts'),
                    icon: const Icon(Icons.switch_account),
                    color: textColor,
                    iconSize: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < destinations.length; i++) ...[
          if (i == homeCount) const Divider(),
          NavigationDrawerDestination(
            label: Text(destinations[i].label),
            icon: destinations[i].icon,
            selectedIcon: destinations[i].selectedIcon,
            enabled: destinations[i].enabled,
          ),
        ],
      ],
    );
  }

  NavigationBar? navBar(BuildContext context) {
    final dest = _supportedHomeDestinations();
    if (dest.defs.isEmpty) return null;

    final current = widget.navigationShell.currentIndex;
    final selectedInBar = dest.indexes.indexOf(current);
    return NavigationBar(
      destinations: [
        for (final def in dest.defs)
          NavigationDestination(
            label: def.label(context),
            icon: def.icon,
            selectedIcon: def.selectedIcon,
          ),
      ],
      selectedIndex: selectedInBar < 0 ? 0 : selectedInBar,
      onDestinationSelected: (int index) => _goBranch(dest.indexes[index]),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    );
  }

  Widget? navRail(BuildContext context) {
    final destinations = <NavigationRailDestination>[];
    final onSelected = <VoidCallback>[];
    final branchIndexes = <int>[];

    void addBranch({
      required String label,
      required Icon icon,
      required Icon selectedIcon,
      required int branchIndex,
    }) {
      destinations.add(
        NavigationRailDestination(
          label: Text(label),
          icon: icon,
          selectedIcon: selectedIcon,
        ),
      );
      branchIndexes.add(branchIndex);
      onSelected.add(() => _goBranch(branchIndex));
    }

    for (final def in AppDefinitions.homeApplets) {
      if (!_supports(def.appletPhpUrl)) continue;
      addBranch(
        label: def.label(context),
        icon: def.icon,
        selectedIcon: def.selectedIcon,
        branchIndex: shellBranchIndexForApplet(def),
      );
    }
    for (final def in AppDefinitions.navigationApplets) {
      if (!_supports(def.appletPhpUrl)) continue;
      addBranch(
        label: def.label(context),
        icon: def.icon,
        selectedIcon: def.selectedIcon,
        branchIndex: shellBranchIndexForApplet(def),
      );
    }
    addBranch(
      label: AppLocalizations.of(context).settings,
      icon: const Icon(Icons.settings),
      selectedIcon: const Icon(Icons.settings),
      branchIndex: settingsShellBranchIndex,
    );

    for (final ext in AppDefinitions.external) {
      if (!ext.showInNavigationRail) continue;
      destinations.add(
        NavigationRailDestination(
          label: Text(ext.label(context)),
          icon: ext.icon,
          selectedIcon: ext.icon,
        ),
      );
      branchIndexes.add(-1);
      onSelected.add(() => ext.action?.call(context));
    }

    if (destinations.isEmpty) return null;

    final current = widget.navigationShell.currentIndex;
    final selectedInRail = branchIndexes.indexOf(current);

    return NavigationRail(
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
        icon: const Icon(Icons.menu),
        onPressed: () => _drawerKey.currentState?.openDrawer(),
      ),
      selectedIndex: selectedInRail < 0 ? 0 : selectedInRail,
      onDestinationSelected: (int index) {
        if (index >= 0 && index < onSelected.length) {
          onSelected[index]();
        }
      },
      labelType: NavigationRailLabelType.all,
      destinations: destinations,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(supportedAppletPhpUrlsProvider);
    ref.watch(activeAccountProvider);

    final anySupported = homeAppletPhpUrls.any(_supports);
    final isTablet = Responsive.isTablet(context);
    final onHomeBranch = _onHomeBranch;
    final bar = (!isTablet && onHomeBranch) ? navBar(context) : null;
    final rail = isTablet ? navRail(context) : null;
    final content = anySupported
        ? widget.navigationShell
        : noAppsSupported();

    // On phone, system back from storage/settings returns to the last home tab
    // instead of leaving the app. Tablet leaves via the rail.
    return PopScope(
      canPop: isTablet || onHomeBranch,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isTablet || onHomeBranch) return;
        _returnToLastHomeBranch();
      },
      child: Scaffold(
        key: _drawerKey,
        body: isTablet && rail != null
            ? Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      // Swipe right on the rail opens the drawer.
                      if (velocity > 250) {
                        _drawerKey.currentState?.openDrawer();
                      }
                    },
                    child: rail,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: content),
                ],
              )
            : content,
        bottomNavigationBar: anySupported ? bar : null,
        drawer: navDrawer(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      ),
    );
  }
}

/// Helper for applet bodies that need an open-drawer callback.
void Function() openHomeDrawer(BuildContext context) {
  final scaffold = Scaffold.maybeOf(context);
  return () => scaffold?.openDrawer();
}
