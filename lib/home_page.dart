import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:lanis/core/database/account_database/account_db.dart';
import 'package:lanis/core/sph/session.dart';
import 'package:lanis/models/account_types.dart';
import 'package:lanis/models/client_status_exceptions.dart';
import 'package:lanis/generated/l10n.dart';

import 'package:flutter/material.dart';
import 'package:lanis/utils/authentication_state.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/utils/whats_new.dart';
import 'package:lanis/utils/cached_network_image.dart';
import 'package:lanis/view/account_switcher/account_switcher.dart';
import 'package:lanis/view/settings/settings.dart';
import 'package:lanis/widgets/dynamic_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import 'applets/definitions.dart';
import 'core/sph/sph.dart';
import 'utils/back_navigation_manager.dart';

typedef ActionFunction = void Function(BuildContext, GlobalKey<NavigatorState>);
typedef WidgetWithContextCallback = Widget Function(BuildContext context);

int selectedDestinationDrawer = -1;
final GlobalKey<HomePageState> homeKey = GlobalKey<HomePageState>();

class Destination {
  final WidgetWithContextCallback icon;
  final WidgetWithContextCallback selectedIcon;
  final bool enableBottomNavigation;
  final bool enableDrawer;
  final bool addDivider;
  final bool hideInRail;
  final String Function(BuildContext) label;
  final ActionFunction? action;
  final Widget Function(BuildContext, AccountType, Function openDrawerCb)? body;
  final String? routeName;
  late final bool isSupported;

  Destination(
      {this.body,
      this.action,
      this.addDivider = false,
      this.hideInRail = false,
      required this.isSupported,
      required this.enableBottomNavigation,
      required this.enableDrawer,
      required this.icon,
      required this.selectedIcon,
      required this.label,
      this.routeName});

  factory Destination.fromAppletDefinition(AppletDefinition appletDefinition) {
    return Destination(
      body: appletDefinition.bodyBuilder,
      action: null,
      addDivider: appletDefinition.addDivider,
      isSupported: sph!.session.doesSupportFeature(appletDefinition),
      enableBottomNavigation: appletDefinition.useBottomNavigation,
      enableDrawer: true,
      icon: appletDefinition.icon,
      selectedIcon: appletDefinition.selectedIcon,
      label: appletDefinition.label,
      routeName: '/applet_${appletDefinition.runtimeType.toString()}',
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _drawerKey = GlobalKey();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool doesSupportAnyApplet = true;
  List<Destination> destinations = [];
  bool isFirstLevelRoute = true;
  int? lastAppletWithBottomNavSupport;

  void checkFirstLevelRoute() {
    navigatorKey.currentState?.popUntil((route) {
      setState(() {
        isFirstLevelRoute = route.isFirst;
      });
      return true;
    });
  }

  void resetState() {
    doesSupportAnyApplet = true;
    lastAppletWithBottomNavSupport = null;
    setState(() {
      selectedDestinationDrawer = -1;
      destinations.clear();
      for (var destination in AppDefinitions.applets) {
        destinations.add(Destination.fromAppletDefinition(destination));
      }
      destinations.addAll(endDestinations);
      setDefaultDestination();
      navigateToInitialDestination();
    });
  }

  @override
  void initState() {
    for (var destination in AppDefinitions.applets) {
      destinations.add(Destination.fromAppletDefinition(destination));
    }
    destinations.addAll(endDestinations);
    setDefaultDestination();
    super.initState();
    showUpdateInfoIfRequired(context);
    navigateToInitialDestination();
  }

  final List<Destination> endDestinations = [
    Destination(
        label: (context) => AppLocalizations.of(context).openLanisInBrowser,
        icon: (context) => const Icon(Icons.open_in_new),
        selectedIcon: (context) => const Icon(Icons.open_in_new),
        isSupported: true,
        enableBottomNavigation: false,
        enableDrawer: true,
        action: (context, navigator) {
          SessionHandler.getLoginURL(sph!.account).then((response) {
            launchUrl(Uri.parse(response));
          });
        }),
    Destination(
      label: (context) => AppLocalizations.of(context).settings,
      icon: (context) => const Icon(Icons.settings),
      selectedIcon: (context) => const Icon(Icons.settings),
      isSupported: true,
      enableBottomNavigation: false,
      enableDrawer: true,
      addDivider: true,
      body: (context, accType, openDrawerCb) => const SettingsScreen(),
      routeName: '/settings',
    ),
    Destination(
        isSupported: true,
        enableBottomNavigation: false,
        hideInRail: true,
        enableDrawer: true,
        icon: (context) => Icon(Icons.logout),
        selectedIcon: (context) => Icon(Icons.logout_outlined),
        label: (context) => AppLocalizations.of(context).logout,
        action: (context, navigator) async {
          await sph!.session.deAuthenticate();
          await accountDatabase.deleteAccount(sph!.account.localId);
          if (context.mounted) authenticationState.reset(context);
        }),
  ];

  void setDefaultDestination() {
    for (var destination in destinations) {
      if (destination.isSupported && destination.enableBottomNavigation) {
        selectedDestinationDrawer = destinations.indexOf(destination);
        lastAppletWithBottomNavSupport = selectedDestinationDrawer;
        doesSupportAnyApplet = true;
        return;
      }
    }
    doesSupportAnyApplet = false;
    selectedDestinationDrawer = -1;
    lastAppletWithBottomNavSupport = null;
  }

  void openLanisInBrowser(BuildContext? context) {
    SessionHandler.getLoginURL(sph!.account).then((response) {
      launchUrl(Uri.parse(response));
    }).catchError((ex) {
      if (context == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ex.cause),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(
          label: 'ACTION',
          onPressed: () {},
        ),
      ));
    }, test: (e) => e is LanisException);
  }

  Widget noAppsSupported() {
    return Scaffold(
      body: Center(
        // In case no feature is supported at all just show an open in browser button.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.disabled_by_default_outlined,
              size: 150,
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(AppLocalizations.of(context).noSupportOpenInBrowser),
            ),
            ElevatedButton(
                onPressed: () => openLanisInBrowser(context),
                child: Text(AppLocalizations.of(context).openLanisInBrowser))
          ],
        ),
      ),
    );
  }

  void openDestination(int index, bool fromDrawer) {
    if (index == selectedDestinationDrawer) return;
    if (destinations[index].action != null) {
      destinations[index].action!(context, navigatorKey);
    } else {
      AppBarController.instance.clear();
      // Use pushReplacement with named routes
      if (destinations[index].routeName != null) {
        navigatorKey.currentState?.pushReplacementNamed(
          destinations[index].routeName!,
          arguments: index,
        );
      }

      setState(() {
        selectedDestinationDrawer = index;
        if (fromDrawer) Navigator.pop(context);
      });
    }
    if (destinations[index].enableBottomNavigation) {
      lastAppletWithBottomNavSupport = index;
    }
  }

  void navigateToInitialDestination() {
    if (selectedDestinationDrawer >= 0 &&
        destinations[selectedDestinationDrawer].routeName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushReplacementNamed(
          destinations[selectedDestinationDrawer].routeName!,
          arguments: selectedDestinationDrawer,
        );
      });
    }
  }

  NavigationDrawer navDrawer(context) {
    List<Widget> drawerDestinations = [];

    for (var destination in destinations) {
      if (destination.enableDrawer) {
        if (destination.addDivider) {
          drawerDestinations.add(const Divider());
        }
        drawerDestinations.add(NavigationDrawerDestination(
          label: Text(destination.label(context)),
          icon: destination.icon(context),
          selectedIcon: destination.selectedIcon(context),
          enabled: destination.isSupported,
        ));
      }
    }

    final Color imageColor =
        Theme.of(context).colorScheme.inversePrimary.withValues(alpha: 0.5);
    final Color textColor =
        imageColor.computeLuminance() < 0.5 ? Colors.white : Colors.black;

    return NavigationDrawer(
        selectedIndex: selectedDestinationDrawer,
        onDestinationSelected: (int index) => openDestination(index, true),
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
                          colorFilter:
                              ColorFilter.mode(imageColor, BlendMode.srcOver),
                          child: AspectRatio(
                            aspectRatio: 16 / 8,
                            child: CachedNetworkImage(
                              imageUrl: Uri.parse(
                                  "https://startcache.schulportal.hessen.de/exporteur.php?a=schoolbg&i=${sph!.account.schoolID}&s=xs"),
                              placeholder: const Image(
                                image: AssetImage("assets/icon.png"),
                                fit: BoxFit.cover,
                              ),
                              builder: (BuildContext context,
                                  ImageProvider<Object> imageProvider) {
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
                            "${sph?.session.userData["nachname"]}, ${sph?.session.userData["vorname"]}",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: textColor),
                          ),
                          Text(
                            sph!.account.schoolName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: textColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(top: 2, right: 2),
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => AccountSwitcher()));
                      },
                      icon: Icon(Icons.switch_account),
                      color: textColor,
                      iconSize: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...drawerDestinations,
        ]);
  }

  NavigationBar? navBar(context) {
    List<NavigationDestination> barDestinations = [];

    for (var destination in destinations) {
      if (destination.enableBottomNavigation && destination.isSupported) {
        barDestinations.add(NavigationDestination(
          label: destination.label(context),
          icon: destination.icon(context),
          selectedIcon: destination.selectedIcon(context),
          enabled: destination.isSupported,
        ));
      }
    }

    List<int?> indexNavbarTranslationLayer = [];

    int helpIndex = 0;
    for (var destination in destinations) {
      if (destination.enableBottomNavigation && destination.isSupported) {
        indexNavbarTranslationLayer.add(helpIndex);
        helpIndex += 1;
      } else {
        indexNavbarTranslationLayer.add(null);
      }
    }
    return indexNavbarTranslationLayer[selectedDestinationDrawer] != null
        ? NavigationBar(
            destinations: barDestinations,
            selectedIndex:
                indexNavbarTranslationLayer[selectedDestinationDrawer]!,
            onDestinationSelected: (int index) => openDestination(
                indexNavbarTranslationLayer.indexOf(index), false),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          )
        : null;
  }

  Widget navRail(BuildContext context) {
    List<NavigationRailDestination> railDestinations = [];

    for (var destination in destinations) {
      if (destination.isSupported && !destination.hideInRail) {
        railDestinations.add(NavigationRailDestination(
            label: Text(destination.label(context)),
            icon: destination.icon(context),
            selectedIcon: destination.selectedIcon(context),
            disabled: !destination.isSupported,
            padding: EdgeInsets.only(
                top: destination.addDivider ? 20 : 4, left: 4, right: 4)));
      }
    }

    List<int?> indexNavbarTranslationLayer = [];

    int helpIndex = 0;
    for (var destination in destinations) {
      if (destination.isSupported && !destination.hideInRail) {
        indexNavbarTranslationLayer.add(helpIndex);
        helpIndex += 1;
      } else {
        indexNavbarTranslationLayer.add(null);
      }
    }

    return NavigationRail(
      selectedIndex: indexNavbarTranslationLayer[selectedDestinationDrawer]!,
      onDestinationSelected: (int index) =>
          openDestination(indexNavbarTranslationLayer.indexOf(index), false),
      labelType: NavigationRailLabelType.selected,
      destinations: railDestinations,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      leading: Column(
        spacing: 4.0,
        children: [
          IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              _drawerKey.currentState?.openDrawer();
            },
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            indent: 8,
            endIndent: 8,
            color: Theme.of(context).colorScheme.outline,
          )
        ],
      ),
    );
  }

  void updateShowBottomAppBar(bool show) {
    setState(() {
      showBottomAppBar = show;
    });
  }

  bool showBottomAppBar = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _drawerKey,
      bottomNavigationBar: Responsive.isTablet(context) == false &&
              isFirstLevelRoute &&
              doesSupportAnyApplet &&
              showBottomAppBar
          ? navBar(context)
          : null,
      drawerEdgeDragWidth: Responsive.isTablet(context) ? 100 : 30,
      drawer: navDrawer(context),
      body: Row(
        children: <Widget>[
          if (Responsive.isTablet(context) == true) ...[
            LayoutBuilder(
              builder: (context, constraint) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraint.maxHeight),
                    child: IntrinsicHeight(
                      child: navRail(context),
                    ),
                  ),
                );
              },
            ),
            VerticalDivider(thickness: 1, width: 1),
          ],
          // This is the main content.
          Expanded(
            child: doesSupportAnyApplet
                ? PopScope(
                    canPop: false,
                    onPopInvokedWithResult:
                        (bool didPop, Object? result) async {
                      if (didPop) {
                        return;
                      }

                      if (_drawerKey.currentState?.isDrawerOpen ?? false) {
                        _drawerKey.currentState?.closeDrawer();
                        return;
                      }

                      // First check if any widget can handle back navigation
                      if (await BackNavigationManager
                          .canHandleBackNavigation()) {
                        BackNavigationManager.handleBackNavigation();
                        return;
                      }

                      if (!isFirstLevelRoute) {
                        navigatorKey.currentState?.pop();
                        return;
                      } else {
                        if (Platform.isAndroid) SystemNavigator.pop();
                      }
                    },
                    child: Navigator(
                      key: navigatorKey,
                      onGenerateRoute: (settings) {
                        // Find destination by route name or use selected destination
                        int destinationIndex = selectedDestinationDrawer;

                        if (settings.arguments is int) {
                          destinationIndex = settings.arguments as int;
                        } else if (settings.name != null &&
                            settings.name != '/') {
                          // Find destination by route name
                          for (int i = 0; i < destinations.length; i++) {
                            if (destinations[i].routeName == settings.name) {
                              destinationIndex = i;
                              break;
                            }
                          }
                        }

                        // Validate destination index and ensure it has a body
                        if (destinationIndex < 0 ||
                            destinationIndex >= destinations.length ||
                            destinations[destinationIndex].body == null) {
                          // Find first available destination with a body
                          for (int i = 0; i < destinations.length; i++) {
                            if (destinations[i].body != null &&
                                destinations[i].isSupported) {
                              destinationIndex = i;
                              break;
                            }
                          }
                        }

                        return MaterialPageRoute(
                          settings: settings,
                          builder: (context) => Column(
                            children: [
                              DynamicAppBar(
                                title: destinations[destinationIndex]
                                    .label(context),
                                automaticallyImplyLeading:
                                    !Responsive.isTablet(context),
                              ),
                              Expanded(
                                child: destinations[destinationIndex].body!(
                                    context, sph!.session.accountType, () {
                                  _drawerKey.currentState!.openDrawer();
                                }),
                              )
                            ],
                          ),
                        );
                      },
                    ))
                : noAppsSupported(),
          )
        ],
      ),
    );
  }
}
