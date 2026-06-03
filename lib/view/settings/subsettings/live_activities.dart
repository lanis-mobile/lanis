import 'package:flutter/material.dart';
import 'package:lanis/core/sph/sph.dart';
import 'package:lanis/utils/switch_tile.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';

class LiveActivitySettings extends SettingsColours {
  const LiveActivitySettings({super.key});

  @override
  State<LiveActivitySettings> createState() => _LiveActivitySettingsState();
}

class _LiveActivitySettingsState
    extends SettingsColoursState<LiveActivitySettings> {
  static const _keyLesson = 'live-activity-lesson';
  static const _keySubstitution = 'live-activity-substitution';

  @override
  Widget build(BuildContext context) {
    return SettingsPageWithStreamBuilder(
      backgroundColor: backgroundColor,
      title: const Text('Live Activities'),
      subscription: sph!.prefs.kv.subscribeMultiple([
        _keyLesson,
        _keySubstitution,
      ]),
      builder: (context, snapshot) {
        final lessonEnabled =
            (snapshot.data![_keyLesson] ?? true) == true;
        final substitutionEnabled =
            (snapshot.data![_keySubstitution] ?? true) == true;

        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Live Activities erscheinen auf dem Sperrbildschirm und in der Dynamic Island.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card.filled(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    MinimalSwitchTile(
                      leading: const Icon(Icons.school_outlined),
                      title: const Text('Aktuelle Stunde'),
                      subtitle: const Text(
                        'Zeigt Countdown und nächste Stunde während dem Unterricht',
                      ),
                      value: lessonEnabled,
                      onChanged: (v) =>
                          sph!.prefs.kv.set(_keyLesson, v),
                      useInkWell: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    const Divider(height: 1),
                    MinimalSwitchTile(
                      leading: const Icon(Icons.swap_horiz_rounded),
                      title: const Text('Neue Vertretungen'),
                      subtitle: const Text(
                        'Zeigt neue Vertretungseinträge sobald der Plan aktualisiert wird',
                      ),
                      value: substitutionEnabled,
                      onChanged: (v) =>
                          sph!.prefs.kv.set(_keySubstitution, v),
                      useInkWell: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
    );
  }
}
