import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/models/account_types.dart';
import 'package:lanis/utils/auth_controller.dart';
import 'package:lanis/utils/cached_network_image.dart';
import 'package:lanis/utils/whats_new.dart';
import 'package:url_launcher/url_launcher.dart';

/// Nested home applet paths (order matches bottom-nav / shell branches).
const homeAppletPaths = [
  '/home/substitutions',
  '/home/calendar',
  '/home/timetable',
  '/home/conversations',
  '/home/lessons',
];

const homeAppletPhpUrls = [
  'vertretungsplan.php',
  'kalender.php',
  'stundenplan.php',
  'nachrichten.php',
  'meinunterricht.php',
];

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

  SessionHandler? get _session => ref.read(sessionProvider).asData?.value;

  ClearTextAccount? get _account => ref.read(activeAccountProvider);

  bool _supports(String phpUrl) =>
      ref.read(supportedAppletPhpUrlsProvider).contains(phpUrl);

  Future<void> _openLanisInBrowser() async {
    final account = _account;
    final config = ref.read(sphConfigProvider);
    if (account == null) return;
    try {
      final url = await SessionHandler.getLoginURL(account, config);
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
    if (account != null) {
      await ref.read(sessionProvider.notifier).deAuthenticate();
      await ref.read(accountsProvider.notifier).remove(account.localId);
    }
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/welcome');
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

  NavigationDrawer navDrawer(BuildContext context) {
    final account = _account;
    final session = _session;
    final nestedDefs = AppDefinitions.applets
        .where((a) => a.appletType == AppletType.nested)
        .toList();

    final Color imageColor = Theme.of(
      context,
    ).colorScheme.inversePrimary.withValues(alpha: 0.5);
    final Color textColor = imageColor.computeLuminance() < 0.5
        ? Colors.white
        : Colors.black;

    final drawerItems = <Widget>[];
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

    // Extra drawer actions after nested applets
    drawerItems.add(const Divider());
    final extras = <({String label, Icon icon, VoidCallback onTap})>[
      if (_supports('dateispeicher.php'))
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
      (
        label: AppLocalizations.of(context).openMoodle,
        icon: const Icon(Icons.open_in_new),
        onTap: () => context.push('/moodle'),
      ),
      (
        label: AppLocalizations.of(context).openLanisInBrowser,
        icon: const Icon(Icons.open_in_new),
        onTap: _openLanisInBrowser,
      ),
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

    final nestedCount = nestedDefs.length;

    return NavigationDrawer(
      selectedIndex: widget.navigationShell.currentIndex.clamp(0, nestedCount - 1),
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
        const Divider(),
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
    final nestedDefs = AppDefinitions.applets
        .where((a) => a.appletType == AppletType.nested)
        .toList();
    final supportedIndexes = <int>[];
    final barDestinations = <NavigationDestination>[];
    for (var i = 0; i < nestedDefs.length; i++) {
      if (_supports(nestedDefs[i].appletPhpUrl)) {
        supportedIndexes.add(i);
        barDestinations.add(
          NavigationDestination(
            label: nestedDefs[i].label(context),
            icon: nestedDefs[i].icon,
            selectedIcon: nestedDefs[i].selectedIcon,
          ),
        );
      }
    }
    if (barDestinations.isEmpty) return null;

    final current = widget.navigationShell.currentIndex;
    final selectedInBar = supportedIndexes.indexOf(current);
    return NavigationBar(
      destinations: barDestinations,
      selectedIndex: selectedInBar < 0 ? 0 : selectedInBar,
      onDestinationSelected: (int index) => _goBranch(supportedIndexes[index]),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(supportedAppletPhpUrlsProvider);
    ref.watch(activeAccountProvider);

    final anySupported = homeAppletPhpUrls.any(_supports);
    final bar = navBar(context);

    return Scaffold(
      key: _drawerKey,
      body: anySupported
          ? widget.navigationShell
          : noAppsSupported(),
      bottomNavigationBar: anySupported ? bar : null,
      drawer: navDrawer(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
    );
  }
}

/// Helper for applet bodies that need an open-drawer callback.
void Function() openHomeDrawer(BuildContext context) {
  final scaffold = Scaffold.maybeOf(context);
  return () => scaffold?.openDrawer();
}
