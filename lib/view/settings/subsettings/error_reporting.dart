import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/glitchtip.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:lanis/view/settings/subsettings/debug_export.dart';
import 'package:lanis/widgets/switch_tile.dart';
import 'package:liblanis/liblanis.dart';

class ErrorReportingSettings extends ConsumerSettingsColours {
  final bool showBackButton;

  const ErrorReportingSettings({super.key, this.showBackButton = true});

  @override
  ConsumerState<ErrorReportingSettings> createState() =>
      _ErrorReportingSettingsState();
}

class _ErrorReportingSettingsState
    extends ConsumerSettingsColoursState<ErrorReportingSettings> {
  @override
  Widget build(BuildContext context) {
    final shared = ref.read(sharedOverAccountSettingsProvider);
    final enabled = isGlitchTipEnabled(shared);
    final accountCount =
        ref.watch(accountsProvider).asData?.value.length ?? 0;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SettingsPage(
      backgroundColor: backgroundColor,
      title: Text(l10n.errorReporting),
      showBackButton: widget.showBackButton,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setGlitchTipEnabled(shared, !enabled);
              setState(() {});
            },
            child: Card.filled(
              color: theme.colorScheme.primaryContainer,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ),
                child: MinimalSwitchTile(
                  title: Text(
                    l10n.errorReportingSwitch,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  value: enabled,
                  onChanged: (value) {
                    setGlitchTipEnabled(shared, value);
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20.0,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            l10n.errorReportingBody,
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (accountCount > 1) ...[
          const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              l10n.errorReportingDeviceWide,
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24.0),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: Text(l10n.debugExport),
          subtitle: Text(l10n.debugExportSubtitle),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const DebugExport()),
            );
          },
        ),
      ],
    );
  }
}
