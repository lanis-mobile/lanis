import 'package:flutter/material.dart';
import 'package:lanis/core/sph/sph.dart';
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

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(value: value, onChanged: onChanged, padding: EdgeInsets.zero),
          ],
        ),
      ),
    );
  }

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
        final lessonEnabled = (snapshot.data![_keyLesson] ?? true) == true;
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
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  _tile(
                    icon: Icons.school_outlined,
                    title: 'Aktuelle Stunde',
                    subtitle: 'Countdown und nächste Stunde im Unterricht',
                    value: lessonEnabled,
                    onChanged: (v) => sph!.prefs.kv.set(_keyLesson, v),
                  ),
                  const Divider(height: 1, indent: 56),
                  _tile(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Neue Vertretungen',
                    subtitle: 'Bei Plan-Aktualisierung auf dem Sperrbildschirm',
                    value: substitutionEnabled,
                    onChanged: (v) => sph!.prefs.kv.set(_keySubstitution, v),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
    );
  }
}
