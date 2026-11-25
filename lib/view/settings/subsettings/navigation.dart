import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/applet_navigation_order.dart';
import 'package:lanis/view/settings/settings.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';

class NavigationSettings extends ConsumerSettingsColours {
  final bool showBackButton;

  const NavigationSettings({super.key, this.showBackButton = true});

  @override
  ConsumerState<NavigationSettings> createState() => _NavigationSettingsState();
}

class _NavigationSettingsState
    extends ConsumerSettingsColoursState<NavigationSettings> {
  void _persistSections(
    AppletNavigationLayout currentLayout,
    List<AppletDefinition> nextBottom,
    List<AppletDefinition> nextDrawer,
  ) {
    final updated = currentLayout.withVisibleSections(
      visibleBottomBar: nextBottom,
      visibleDrawer: nextDrawer,
    );
    saveAppletNavigationLayout(ref, updated);
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required Key key,
    required String title,
    String? trailingBadge,
    String? subtitle,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  }) {
    final theme = Theme.of(context);
    return Padding(
      key: key,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge!.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              if (trailingBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trailingBadge,
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppletTile(
    BuildContext context, {
    required AppletDefinition def,
    required int flatIndex,
    required int sectionIndex,
    required int sectionLength,
    required bool inBottomBar,
    required bool bottomBarFull,
    required VoidCallback onToggleSection,
  }) {
    final l10n = AppLocalizations.of(context);
    final borderRadius = SettingsTileWidget.getRadius(
      sectionIndex,
      sectionLength,
    );
    final canMoveToBottomBar = !inBottomBar && !bottomBarFull;

    return Padding(
      key: ValueKey('applet-${def.pathSegment}'),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 1.0),
      child: ReorderableDelayedDragStartListener(
        index: flatIndex,
        child: Material(
          color: foregroundColor,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: def.icon,
            title: Text(def.label(context)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: inBottomBar
                      ? l10n.navigationMoveToSidebar
                      : (bottomBarFull
                            ? l10n.navigationBottomBarFull
                            : l10n.navigationMoveToBottomBar),
                  icon: Icon(
                    inBottomBar
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                  onPressed: inBottomBar || canMoveToBottomBar
                      ? onToggleSection
                      : null,
                ),
                ReorderableDragStartListener(
                  index: flatIndex,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 8.0,
                    ),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final supported = ref.watch(supportedAppletPhpUrlsProvider);
    final accountType = ref.watch(
      activeAccountProvider.select((a) => a?.accountType),
    );
    final layout = ref.watch(appletNavigationLayoutProvider);

    final bottomDefs = layout.supportedBottomBar(
      supportedPhpUrls: supported,
      accountType: accountType,
    );
    final drawerDefs = layout.supportedDrawer(
      supportedPhpUrls: supported,
      accountType: accountType,
    );
    final isDefault = layout.isDefaultFor(
      supportedPhpUrls: supported,
      accountType: accountType,
    );
    final bottomBarFull = bottomDefs.length >= maxBottomBarApplets;

    final String? bottomHint;
    if (bottomDefs.isEmpty) {
      bottomHint = l10n.navigationBottomBarEmptyHint;
    } else if (bottomDefs.length < minBottomBarAppletsForDisplay) {
      bottomHint = l10n.navigationBottomBarMinHint;
    } else {
      bottomHint = null;
    }

    final rows = <Widget>[
      _buildSectionHeader(
        context,
        key: const ValueKey('header-bottom-bar'),
        title: l10n.navigationBottomBarSection,
        trailingBadge: l10n.navigationBottomBarCount(
          bottomDefs.length,
          maxBottomBarApplets,
        ),
        subtitle: bottomHint,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      ),
      for (var i = 0; i < bottomDefs.length; i++)
        _buildAppletTile(
          context,
          def: bottomDefs[i],
          flatIndex: 1 + i,
          sectionIndex: i,
          sectionLength: bottomDefs.length,
          inBottomBar: true,
          bottomBarFull: bottomBarFull,
          onToggleSection: () {
            final moved = moveAppletToDrawer(
              bottomBar: bottomDefs,
              drawer: drawerDefs,
              def: bottomDefs[i],
            );
            _persistSections(layout, moved.bottomBar, moved.drawer);
          },
        ),
      _buildSectionHeader(
        context,
        key: const ValueKey('header-drawer'),
        title: l10n.navigationSidebarSection,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      ),
      for (var i = 0; i < drawerDefs.length; i++)
        _buildAppletTile(
          context,
          def: drawerDefs[i],
          flatIndex: 2 + bottomDefs.length + i,
          sectionIndex: i,
          sectionLength: drawerDefs.length,
          inBottomBar: false,
          bottomBarFull: bottomBarFull,
          onToggleSection: () {
            final moved = moveAppletToBottomBar(
              bottomBar: bottomDefs,
              drawer: drawerDefs,
              def: drawerDefs[i],
            );
            _persistSections(layout, moved.bottomBar, moved.drawer);
          },
        ),
    ];

    return SettingsPage(
      backgroundColor: backgroundColor,
      title: Text(l10n.navigation),
      showBackButton: widget.showBackButton,
      children: [
        ReorderableListView(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.only(bottom: 24.0),
          proxyDecorator: (child, index, animation) {
            return Material(
              elevation: 4,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12.0),
              child: child,
            );
          },
          onReorderItem: (oldIndex, newIndex) {
            final reordered = reorderAppletSections(
              bottomBar: bottomDefs,
              drawer: drawerDefs,
              oldIndex: oldIndex,
              newIndex: newIndex,
            );
            _persistSections(layout, reordered.bottomBar, reordered.drawer);
          },
          footer: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: isDefault
                      ? null
                      : () => resetAppletNavigationLayout(ref),
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(l10n.navigationResetOrder),
                ),
                const SizedBox(height: 20.0),
                Icon(
                  Icons.info_outline_rounded,
                  size: 20.0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8.0),
                Text(
                  l10n.navigationSettingsInfo,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          children: rows,
        ),
      ],
    );
  }
}
