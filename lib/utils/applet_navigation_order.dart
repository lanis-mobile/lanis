import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/shell_navigation.dart';

/// Material 3 phone [NavigationBar] caps destinations at 5.
const int maxBottomBarApplets = 5;

/// Flutter's [NavigationBar] requires at least 2 destinations to display.
const int minBottomBarAppletsForDisplay = 2;

/// Account-scoped [TypedSettings] key for per-account applet navigation layout.
const String appletNavigationOrderSettingsKey = 'applet-navigation-order';

/// Current schema version for serialized [AppletNavigationLayout] JSON.
const int appletNavigationLayoutSchemaVersion = 1;

/// Per-account layout partitioning Lanis applets into the phone bottom bar
/// section and the sidebar/drawer section, in display order.
class AppletNavigationLayout {
  final List<AppletDefinition> bottomBar;
  final List<AppletDefinition> drawer;

  const AppletNavigationLayout({required this.bottomBar, required this.drawer});

  /// Default layout matching [AppDefinitions.homeApplets] and
  /// [AppDefinitions.navigationApplets].
  factory AppletNavigationLayout.defaults() {
    return AppletNavigationLayout(
      bottomBar: List<AppletDefinition>.unmodifiable(
        AppDefinitions.homeApplets,
      ),
      drawer: List<AppletDefinition>.unmodifiable(
        AppDefinitions.navigationApplets,
      ),
    );
  }

  /// Normalizes persisted JSON against the current [AppDefinitions.applets].
  ///
  /// Unknown/removed segments and duplicates are ignored. Newly added applets
  /// not present in [raw] are appended to their default section (nested applets
  /// join [bottomBar] only if it has fewer than [maxBottomBarApplets] entries;
  /// otherwise they are appended to [drawer]).
  ///
  /// Note: [bottomBar] is not hard-truncated to [maxBottomBarApplets] during
  /// deserialization so that hidden/unsupported applets preserved in their
  /// original section do not evict supported bottom-bar applets. Display
  /// consumers always cap visible bottom-bar items via [supportedBottomBar].
  factory AppletNavigationLayout.fromJson(Map<String, dynamic>? raw) {
    if (raw == null) return AppletNavigationLayout.defaults();
    final rawBottom = raw['bottomBar'];
    final rawDrawer = raw['drawer'];
    if (rawBottom is! List && rawDrawer is! List) {
      return AppletNavigationLayout.defaults();
    }

    final bySegment = {
      for (final def in AppDefinitions.applets) def.pathSegment: def,
    };
    final seen = <String>{};
    final bottom = <AppletDefinition>[];
    final side = <AppletDefinition>[];

    if (rawBottom is List) {
      for (final item in rawBottom) {
        if (item is! String) continue;
        final def = bySegment[item];
        if (def == null || !seen.add(def.pathSegment)) continue;
        bottom.add(def);
      }
    }

    if (rawDrawer is List) {
      for (final item in rawDrawer) {
        if (item is! String) continue;
        final def = bySegment[item];
        if (def == null || !seen.add(def.pathSegment)) continue;
        side.add(def);
      }
    }

    for (final def in AppDefinitions.applets) {
      if (!seen.add(def.pathSegment)) continue;
      if (def.appletType == AppletType.nested &&
          bottom.length < maxBottomBarApplets) {
        bottom.add(def);
      } else {
        side.add(def);
      }
    }

    return AppletNavigationLayout(
      bottomBar: List<AppletDefinition>.unmodifiable(bottom),
      drawer: List<AppletDefinition>.unmodifiable(side),
    );
  }

  /// All applets in custom order: [bottomBar] followed by [drawer].
  List<AppletDefinition> get all => [...bottomBar, ...drawer];

  static bool _supportsApplet(
    AppletDefinition def, {
    required Set<String> supportedPhpUrls,
    required AccountType? accountType,
  }) {
    return accountType != null &&
        def.supportedAccountTypes.contains(accountType) &&
        supportedPhpUrls.contains(def.appletPhpUrl);
  }

  /// Supported applets assigned to the phone bottom bar (at most
  /// [maxBottomBarApplets]).
  List<AppletDefinition> supportedBottomBar({
    required Set<String> supportedPhpUrls,
    required AccountType? accountType,
  }) {
    return bottomBar
        .where(
          (def) => _supportsApplet(
            def,
            supportedPhpUrls: supportedPhpUrls,
            accountType: accountType,
          ),
        )
        .take(maxBottomBarApplets)
        .toList(growable: false);
  }

  /// Supported applets assigned to the sidebar/drawer only.
  List<AppletDefinition> supportedDrawer({
    required Set<String> supportedPhpUrls,
    required AccountType? accountType,
  }) {
    final activeBottom = supportedBottomBar(
      supportedPhpUrls: supportedPhpUrls,
      accountType: accountType,
    );
    final bottomSegments = {for (final def in activeBottom) def.pathSegment};
    return all
        .where(
          (def) =>
              !bottomSegments.contains(def.pathSegment) &&
              _supportsApplet(
                def,
                supportedPhpUrls: supportedPhpUrls,
                accountType: accountType,
              ),
        )
        .toList(growable: false);
  }

  /// All supported applets in custom order (bottom bar first, then drawer).
  List<AppletDefinition> supportedAll({
    required Set<String> supportedPhpUrls,
    required AccountType? accountType,
  }) {
    return [
      ...supportedBottomBar(
        supportedPhpUrls: supportedPhpUrls,
        accountType: accountType,
      ),
      ...supportedDrawer(
        supportedPhpUrls: supportedPhpUrls,
        accountType: accountType,
      ),
    ];
  }

  /// Shell branch indices currently pinned to the bottom bar for this account.
  List<int> supportedBottomBarBranchIndexes({
    required Set<String> supportedPhpUrls,
    required AccountType? accountType,
  }) {
    return supportedBottomBar(
      supportedPhpUrls: supportedPhpUrls,
      accountType: accountType,
    ).map(shellBranchIndexForApplet).toList(growable: false);
  }

  /// Whether [branchIndex] is currently in the account's bottom bar.
  bool isBottomBarBranch(
    int branchIndex, {
    required Set<String> supportedPhpUrls,
    required AccountType? accountType,
  }) {
    return supportedBottomBarBranchIndexes(
      supportedPhpUrls: supportedPhpUrls,
      accountType: accountType,
    ).contains(branchIndex);
  }

  /// Returns a new layout combining updated visible (account-supported)
  /// sections while keeping any currently hidden/unsupported applets in their
  /// original section and relative position.
  ///
  /// This ensures that saving while the supported applet set is temporarily
  /// incomplete (e.g. offline or a module temporarily disabled) never causes
  /// hidden applets to lose their bottom-bar slot permanently.
  AppletNavigationLayout withVisibleSections({
    required List<AppletDefinition> visibleBottomBar,
    required List<AppletDefinition> visibleDrawer,
  }) {
    final seenVisible = <String>{};
    final clampedBottom = <AppletDefinition>[];
    final clampedDrawer = <AppletDefinition>[];

    for (final def in visibleBottomBar) {
      if (!seenVisible.add(def.pathSegment)) continue;
      if (clampedBottom.length < maxBottomBarApplets) {
        clampedBottom.add(def);
      } else {
        clampedDrawer.add(def);
      }
    }
    for (final def in visibleDrawer) {
      if (!seenVisible.add(def.pathSegment)) continue;
      clampedDrawer.add(def);
    }

    List<AppletDefinition> mergeSection(
      List<AppletDefinition> previousSection,
      List<AppletDefinition> nextVisibleSection,
    ) {
      final result = <AppletDefinition>[];
      var visibleCursor = 0;
      for (final item in previousSection) {
        if (!seenVisible.contains(item.pathSegment)) {
          // Hidden/unsupported item: keep its original section & slot.
          result.add(item);
        } else if (visibleCursor < nextVisibleSection.length) {
          result.add(nextVisibleSection[visibleCursor++]);
        }
      }
      while (visibleCursor < nextVisibleSection.length) {
        result.add(nextVisibleSection[visibleCursor++]);
      }
      return result;
    }

    final nextBottom = mergeSection(bottomBar, clampedBottom);
    final nextDrawer = mergeSection(drawer, clampedDrawer);

    final accounted = {
      for (final def in nextBottom) def.pathSegment,
      for (final def in nextDrawer) def.pathSegment,
    };
    for (final def in AppDefinitions.applets) {
      if (accounted.add(def.pathSegment)) {
        nextDrawer.add(def);
      }
    }

    return AppletNavigationLayout(
      bottomBar: List<AppletDefinition>.unmodifiable(nextBottom),
      drawer: List<AppletDefinition>.unmodifiable(nextDrawer),
    );
  }

  /// Whether the visible layout for this account matches the default layout.
  bool isDefaultFor({
    required Set<String> supportedPhpUrls,
    required AccountType? accountType,
  }) {
    final defaults = AppletNavigationLayout.defaults();
    return _sameSegments(
          supportedBottomBar(
            supportedPhpUrls: supportedPhpUrls,
            accountType: accountType,
          ),
          defaults.supportedBottomBar(
            supportedPhpUrls: supportedPhpUrls,
            accountType: accountType,
          ),
        ) &&
        _sameSegments(
          supportedDrawer(
            supportedPhpUrls: supportedPhpUrls,
            accountType: accountType,
          ),
          defaults.supportedDrawer(
            supportedPhpUrls: supportedPhpUrls,
            accountType: accountType,
          ),
        );
  }

  Map<String, dynamic> toJson() => {
    'v': appletNavigationLayoutSchemaVersion,
    'bottomBar': bottomBar.map((a) => a.pathSegment).toList(),
    'drawer': drawer.map((a) => a.pathSegment).toList(),
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppletNavigationLayout &&
            _sameSegments(bottomBar, other.bottomBar) &&
            _sameSegments(drawer, other.drawer);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(bottomBar.map((a) => a.pathSegment)),
    Object.hashAll(drawer.map((a) => a.pathSegment)),
  );

  static bool _sameSegments(
    List<AppletDefinition> a,
    List<AppletDefinition> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].pathSegment != b[i].pathSegment) return false;
    }
    return true;
  }
}

/// Distinct sentinels used by [reorderAppletSections] for flat-list reordering.
enum _HeaderSentinel { bottomBar, drawer }

/// Pure reorder transition for a flat [ReorderableListView] laid out as:
/// `[bottomHeader, ...bottomBar, drawerHeader, ...drawer]`.
///
/// Matches [ReorderableListView.onReorderItem] semantics, where [newIndex] is
/// already adjusted for removing the item at [oldIndex].
/// Headers are non-draggable. Dropping an item above the top header clamps it
/// to the first bottom-bar slot. Dragging a drawer item into a full
/// ([maxBottomBarApplets]) bottom bar bumps the displaced last bottom-bar item
/// to the top of [drawer].
({
  List<AppletDefinition> bottomBar,
  List<AppletDefinition> drawer,
  AppletDefinition? bumpedToDrawer,
})
reorderAppletSections({
  required List<AppletDefinition> bottomBar,
  required List<AppletDefinition> drawer,
  required int oldIndex,
  required int newIndex,
}) {
  final items = <Object>[
    _HeaderSentinel.bottomBar,
    ...bottomBar,
    _HeaderSentinel.drawer,
    ...drawer,
  ];

  if (oldIndex < 0 || oldIndex >= items.length) {
    return (bottomBar: bottomBar, drawer: drawer, bumpedToDrawer: null);
  }
  final dragged = items[oldIndex];
  if (dragged is! AppletDefinition) {
    return (bottomBar: bottomBar, drawer: drawer, bumpedToDrawer: null);
  }

  items.removeAt(oldIndex);
  final target = newIndex.clamp(1, items.length);
  items.insert(target, dragged);

  final splitIndex = items.indexOf(_HeaderSentinel.drawer);
  final nextBottom = items
      .sublist(1, splitIndex)
      .cast<AppletDefinition>()
      .toList();
  final nextDrawer = items
      .sublist(splitIndex + 1)
      .cast<AppletDefinition>()
      .toList();

  AppletDefinition? bumped;
  if (nextBottom.length > maxBottomBarApplets) {
    if (identical(nextBottom.last, dragged)) {
      bumped = nextBottom.removeAt(nextBottom.length - 2);
    } else {
      bumped = nextBottom.removeLast();
    }
    nextDrawer.insert(0, bumped);
    while (nextBottom.length > maxBottomBarApplets) {
      nextDrawer.insert(0, nextBottom.removeLast());
    }
  }

  return (bottomBar: nextBottom, drawer: nextDrawer, bumpedToDrawer: bumped);
}

/// Moves [def] from [drawer] to the end of [bottomBar] if space remains.
({List<AppletDefinition> bottomBar, List<AppletDefinition> drawer})
moveAppletToBottomBar({
  required List<AppletDefinition> bottomBar,
  required List<AppletDefinition> drawer,
  required AppletDefinition def,
}) {
  if (bottomBar.length >= maxBottomBarApplets) {
    return (bottomBar: bottomBar, drawer: drawer);
  }
  if (bottomBar.any((a) => a.pathSegment == def.pathSegment)) {
    return (bottomBar: bottomBar, drawer: drawer);
  }
  return (
    bottomBar: [...bottomBar, def],
    drawer: drawer.where((a) => a.pathSegment != def.pathSegment).toList(),
  );
}

/// Moves [def] from [bottomBar] to the top of [drawer].
({List<AppletDefinition> bottomBar, List<AppletDefinition> drawer})
moveAppletToDrawer({
  required List<AppletDefinition> bottomBar,
  required List<AppletDefinition> drawer,
  required AppletDefinition def,
}) {
  if (drawer.any((a) => a.pathSegment == def.pathSegment)) {
    return (bottomBar: bottomBar, drawer: drawer);
  }
  return (
    bottomBar: bottomBar
        .where((a) => a.pathSegment != def.pathSegment)
        .toList(),
    drawer: [def, ...drawer],
  );
}

/// Manages per-account read/write access to [AppletNavigationLayout] in one
/// notifier so UI consumers update immediately without a separate revision key.
class AppletNavigationLayoutNotifier extends Notifier<AppletNavigationLayout> {
  @override
  AppletNavigationLayout build() {
    ref.watch(activeAccountProvider.select((a) => a?.localId));
    final settings = ref.watch(accountSpecificSettingsProvider);
    return AppletNavigationLayout.fromJson(
      settings?.getJsonMap(appletNavigationOrderSettingsKey),
    );
  }

  void save(AppletNavigationLayout layout) {
    final settings = ref.read(accountSpecificSettingsProvider);
    if (settings == null) return;
    settings.setJsonMap(appletNavigationOrderSettingsKey, layout.toJson());
    state = layout;
  }

  void reset() {
    final settings = ref.read(accountSpecificSettingsProvider);
    if (settings == null) return;
    settings.remove(appletNavigationOrderSettingsKey);
    state = AppletNavigationLayout.defaults();
  }
}

/// Active account's applet navigation layout (bottom bar + drawer ordering).
final appletNavigationLayoutProvider =
    NotifierProvider<AppletNavigationLayoutNotifier, AppletNavigationLayout>(
      AppletNavigationLayoutNotifier.new,
    );
