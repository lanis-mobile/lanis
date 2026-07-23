import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';

class UserDataSettings extends ConsumerSettingsColours {
  final bool showBackButton;
  const UserDataSettings({super.key, this.showBackButton = true});

  @override
  ConsumerState<UserDataSettings> createState() => _UserDataSettingsState();
}

class _UserDataSettingsState
    extends ConsumerSettingsColoursState<UserDataSettings> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).asData?.value;
    final userData = session?.userData ?? {};

    return SettingsPage(
      title: Text(AppLocalizations.of(context).userData),
      backgroundColor: backgroundColor,
      showBackButton: widget.showBackButton,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        for (var key in userData.keys)
          ListTile(
            title: Text(userData[key]!),
            subtitle: Text(toBeginningOfSentenceCase(key)!),
            contentPadding: EdgeInsets.zero,
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
          AppLocalizations.of(context).settingsInfoUserData,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
