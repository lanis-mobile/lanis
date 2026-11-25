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
  /// Unknown/removed segments and duplicates are ignored. Any overflow beyond
  /// [maxBottomBarApplets] is moved to the start of [drawer]. Newly added
  /// applets not present in [raw] are appended to their default section
  /// (falling back to [drawer] if [bottomBar] is already full).
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
    final overflow = <AppletDefinition>[];
    final side = <AppletDefinition>[];

    if (rawBottom is List) {
      for (final item in rawBottom) {
        if (item is! String) continue;
        final def = bySegment[item];
        if (def == null || !seen.add(def.pathSegment)) continue;
        if (bottom.length < maxBottomBarApplets) {
          bottom.add(def);
        } else {
          overflow.add(def);
        }
      }
    }

    side.addAll(overflow);

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
  /// sections with any hidden/unsupported applets preserved at the end of
  /// [drawer] so they never occupy bottom-bar slots.
  AppletNavigationLayout withVisibleSections({
    required List<AppletDefinition> visibleBottomBar,
    required List<AppletDefinition> visibleDrawer,
  }) {
    final seen = <String>{};
    final nextBottom = <AppletDefinition>[];
    final nextDrawer = <AppletDefinition>[];

    for (final def in visibleBottomBar) {
      if (!seen.add(def.pathSegment)) continue;
      if (nextBottom.length < maxBottomBarApplets) {
        nextBottom.add(def);
      } else {
        nextDrawer.add(def);
      }
    }

    for (final def in visibleDrawer) {
      if (!seen.add(def.pathSegment)) continue;
      nextDrawer.add(def);
    }

    for (final def in all) {
      if (seen.add(def.pathSegment)) {
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
    if (identical(nextBottom.last, dragged) &&
        nextBottom.length >= 2 &&
        nextBottom.length - 2 >= 0) {
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

class AppletNavigationOrderRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final appletNavigationOrderRevisionProvider =
    NotifierProvider<AppletNavigationOrderRevision, int>(
      AppletNavigationOrderRevision.new,
    );

/// Active account's applet navigation layout (bottom bar + drawer ordering).
final appletNavigationLayoutProvider = Provider<AppletNavigationLayout>((ref) {
  ref.watch(appletNavigationOrderRevisionProvider);
  ref.watch(activeAccountProvider.select((a) => a?.localId));
  final settings = ref.watch(accountSpecificSettingsProvider);
  final raw = settings?.getJsonMap(appletNavigationOrderSettingsKey);
  return AppletNavigationLayout.fromJson(raw);
});

/// Persists [layout] for the active account and refreshes dependents.
void saveAppletNavigationLayout(WidgetRef ref, AppletNavigationLayout layout) {
  final settings = ref.read(accountSpecificSettingsProvider);
  if (settings == null) return;
  settings.setJsonMap(appletNavigationOrderSettingsKey, layout.toJson());
  ref.read(appletNavigationOrderRevisionProvider.notifier).bump();
}

/// Resets the active account's navigation layout back to defaults.
void resetAppletNavigationLayout(WidgetRef ref) {
  final settings = ref.read(accountSpecificSettingsProvider);
  if (settings == null) return;
  settings.remove(appletNavigationOrderSettingsKey);
  ref.read(appletNavigationOrderRevisionProvider.notifier).bump();
}
