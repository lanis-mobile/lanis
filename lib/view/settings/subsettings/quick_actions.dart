import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/switch_tile.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:liblanis/liblanis.dart';

class QuickActions extends ConsumerSettingsColours {
  final bool showBackButton;
  const QuickActions({super.key, this.showBackButton = true});

  @override
  ConsumerState<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends ConsumerSettingsColoursState<QuickActions> {
  // Android supports 2 quick actions, iOS 4
  final int maxQuickActions = Platform.isAndroid ? 2 : 4;

  bool _supports(AppletDefinition applet) {
    final session = ref.read(sessionProvider).asData?.value;
    if (session == null) return false;
    try {
      return session.doesSupportFeature(Applets.byPhpUrl(applet.appletPhpUrl));
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shared = ref.watch(sharedOverAccountSettingsProvider);
    List<AppletDefinition> applets = [];
    for (final applet in AppDefinitions.applets) {
      if (_supports(applet) &&
          (!Platform.isAndroid || applet.appletType != AppletType.navigation)) {
        applets.add(applet);
      }
    }

    final List<String> quickActions = List<String>.from(
      shared.getJsonList('quick-actions') ?? [],
    );
    quickActions.removeWhere((element) => element.isEmpty);

    return SettingsPage(
      title: Text(AppLocalizations.of(context).quickActions),
      backgroundColor: backgroundColor,
      showBackButton: widget.showBackButton,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  AppLocalizations.of(context).applets,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              ...applets.map(
                (applet) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: MinimalSwitchTile(
                    title: Text(applet.label(context)),
                    leading: applet.icon,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                    value: quickActions.contains(applet.appletPhpUrl),
                    onChanged:
                        quickActions.length >= maxQuickActions &&
                            !quickActions.contains(applet.appletPhpUrl)
                        ? null
                        : (bool value) {
                            if (value) {
                              quickActions.add(applet.appletPhpUrl);
                            } else {
                              quickActions.remove(applet.appletPhpUrl);
                            }
                            shared.setJsonList('quick-actions', quickActions);
                            setState(() {});
                          },
                    useInkWell: true,
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  AppLocalizations.of(context).external,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              ...AppDefinitions.external.map(
                (external) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: MinimalSwitchTile(
                    title: Text(external.label(context)),
                    leading: external.icon,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                    value: quickActions.contains(external.id),
                    onChanged:
                        quickActions.length >= maxQuickActions &&
                            !quickActions.contains(external.id)
                        ? null
                        : (bool value) {
                            if (value) {
                              quickActions.add(external.id);
                            } else {
                              quickActions.remove(external.id);
                            }
                            shared.setJsonList('quick-actions', quickActions);
                            setState(() {});
                          },
                    useInkWell: true,
                  ),
                ),
              ),
              SizedBox(height: 24.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20.0,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              SizedBox(height: 8.0),
              Text(
                AppLocalizations.of(context).restartRequired,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 4.0),
              Text(
                AppLocalizations.of(
                  context,
                ).quickActionsDisclaimer(maxQuickActions),
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 4.0),
              if (Platform.isAndroid)
                Text(
                  AppLocalizations.of(context).quickActionsAndroid,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
