import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/nav_rail_settings.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:lanis/widgets/switch_tile.dart';
import 'package:liblanis/liblanis.dart';

class NavigationRailSettingsPage extends ConsumerSettingsColours {
  final bool showBackButton;
  const NavigationRailSettingsPage({super.key, this.showBackButton = true});

  @override
  ConsumerState<NavigationRailSettingsPage> createState() =>
      _NavigationRailSettingsPageState();
}

class _NavigationRailSettingsPageState
    extends ConsumerSettingsColoursState<NavigationRailSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shared = ref.read(sharedOverAccountSettingsProvider);
    final settings = ref.watch(navRailSettingsProvider);

    return SettingsPage(
      backgroundColor: backgroundColor,
      title: Text(l10n.navigationRail),
      showBackButton: widget.showBackButton,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            l10n.navigationRailDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 16.0),
        MinimalSwitchTile(
          title: Text(l10n.navRailShowMoodle),
          leading: const Icon(Icons.school_outlined),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          useInkWell: true,
          value: settings.showMoodle,
          onChanged: (value) {
            shared.setBool(kNavRailShowMoodleKey, value);
            notifyNavRailSettingsChanged(ref);
          },
        ),
        MinimalSwitchTile(
          title: Text(l10n.navRailShowOpenBrowser),
          leading: const Icon(Icons.open_in_browser),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          useInkWell: true,
          value: settings.showOpenBrowser,
          onChanged: (value) {
            shared.setBool(kNavRailShowOpenBrowserKey, value);
            notifyNavRailSettingsChanged(ref);
          },
        ),
      ],
    );
  }
}
