import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/features/auth/auth_controller.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showUpdateInfoIfRequired(context);
    });
  }

  LanisSession? get _session => ref.read(sessionProvider).asData?.value;

  ClearTextAccount? get _account => ref.read(activeAccountProvider);

  bool _supports(String phpUrl) =>
      ref.read(supportedAppletPhpUrlsProvider).contains(phpUrl);

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
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
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

  NavigationDrawer navDrawer(BuildContext context, {required bool isTablet}) {
    final account = _account;
    final session = _session;
    final nestedDefs = AppDefinitions.homeApplets;

    final Color imageColor = Theme.of(
      context,
    ).colorScheme.inversePrimary.withValues(alpha: 0.5);
    final Color textColor = imageColor.computeLuminance() < 0.5
        ? Colors.white
        : Colors.black;

    final drawerItems = <Widget>[];
    if (!isTablet) {
      for (var i = 0; i < nestedDefs.length; i++) {
        final def = nestedDefs[i];
        final supported = _supports(def.appletPhpUrl);
        drawerItems.add(
          NavigationDrawerDestination(
            label: Text(def.label(context)),
            icon: def.icon,
            selectedIcon: def.selectedIcon,
            enabled: supported,
          ),
        );
      }
      drawerItems.add(const Divider());
    }

    final railNavigationApplets = AppDefinitions.navigationApplets
        .where((a) => a.showInNavigationRail)
        .map((a) => a.appletPhpUrl)
        .toSet();
    final railExternals = AppDefinitions.external
        .where((e) => e.showInNavigationRail)
        .map((e) => e.id)
        .toSet();

    final extras = <({String label, Icon icon, VoidCallback onTap})>[
      // Skip items already on the tablet rail.
      if ((!isTablet || !railNavigationApplets.contains('dateispeicher.php')) &&
          _supports('dateispeicher.php'))
        (
          label: AppLocalizations.of(context).storage,
          icon: const Icon(Icons.folder_copy),
          onTap: () => context.push('/storage'),
        ),
      if (_supports('lerngruppen.php'))
        (
          label: AppLocalizations.of(context).studyGroups,
          icon: const Icon(Icons.groups),
          onTap: () => context.push('/study-groups'),
        ),
      if (!isTablet || !railExternals.contains('openMoodle'))
        (
          label: AppLocalizations.of(context).openMoodle,
          icon: const Icon(Icons.open_in_new),
          onTap: () => context.push('/moodle'),
        ),
      if (!isTablet || !railExternals.contains('openLanis'))
        (
          label: AppLocalizations.of(context).openLanisInBrowser,
          icon: const Icon(Icons.open_in_new),
          onTap: _openLanisInBrowser,
        ),
      if (!isTablet)
        (
          label: AppLocalizations.of(context).settings,
          icon: const Icon(Icons.settings),
          onTap: () => context.push('/settings'),
        ),
      (
        label: AppLocalizations.of(context).logout,
        icon: const Icon(Icons.logout),
        onTap: _logout,
      ),
    ];

    final nestedCount = isTablet ? 0 : nestedDefs.length;

    return NavigationDrawer(
      selectedIndex: isTablet
          ? null
          : widget.navigationShell.currentIndex.clamp(0, nestedCount - 1),
      onDestinationSelected: (int index) {
        Navigator.pop(context);
        if (index < nestedCount) {
          _goBranch(index);
        } else {
          final extraIndex = index - nestedCount;
          if (extraIndex >= 0 && extraIndex < extras.length) {
            extras[extraIndex].onTap();
          }
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
        ...drawerItems,
        for (final e in extras)
          NavigationDrawerDestination(
            label: Text(e.label),
            icon: e.icon,
            selectedIcon: e.icon,
          ),
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
    final dest = _supportedHomeDestinations();
    if (dest.defs.isEmpty) return null;

    final l10n = AppLocalizations.of(context);

    final destinations = <NavigationRailDestination>[
      for (final def in dest.defs)
        NavigationRailDestination(
          label: Text(def.label(context)),
          icon: def.icon,
          selectedIcon: def.selectedIcon,
        ),
    ];
    final onSelected = <VoidCallback>[
      for (final branchIndex in dest.indexes) () => _goBranch(branchIndex),
    ];

    void addExtra({
      required String label,
      required Icon icon,
      required VoidCallback onTap,
    }) {
      destinations.add(
        NavigationRailDestination(
          label: Text(label),
          icon: icon,
          selectedIcon: icon,
        ),
      );
      onSelected.add(onTap);
    }

    for (final def in AppDefinitions.navigationApplets) {
      if (!def.showInNavigationRail) continue;
      if (!_supports(def.appletPhpUrl)) continue;
      addExtra(
        label: def.label(context),
        icon: def.icon,
        onTap: () => context.push(def.routePath),
      );
    }

    addExtra(
      label: l10n.settings,
      icon: const Icon(Icons.settings),
      onTap: () => context.push('/settings'),
    );

    for (final ext in AppDefinitions.external) {
      if (!ext.showInNavigationRail) continue;
      addExtra(
        label: ext.label(context),
        icon: ext.icon,
        onTap: () => ext.action?.call(context),
      );
    }

    final current = widget.navigationShell.currentIndex;
    final selectedInRail = dest.indexes.indexOf(current);

    return NavigationRail(
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
    final bar = isTablet ? null : navBar(context);
    final rail = isTablet ? navRail(context) : null;
    final content = anySupported
        ? widget.navigationShell
        : noAppsSupported();

    return Scaffold(
      key: _drawerKey,
      body: isTablet && rail != null
          ? Row(
              children: [
                rail,
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: anySupported ? bar : null,
      drawer: navDrawer(context, isTablet: isTablet),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
    );
  }
}

/// Helper for applet bodies that need an open-drawer callback.
void Function() openHomeDrawer(BuildContext context) {
  final scaffold = Scaffold.maybeOf(context);
  return () => scaffold?.openDrawer();
}
