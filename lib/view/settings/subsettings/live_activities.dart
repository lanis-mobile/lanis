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

  @override
  Widget build(BuildContext context) {
    return SettingsPageWithStreamBuilder(
      backgroundColor: backgroundColor,
      title: const Text('Live Activities'),
      subscription: sph!.prefs.kv.subscribeMultiple([_keyLesson]),
      builder: (context, snapshot) {
        final lessonEnabled = (snapshot.data![_keyLesson] ?? true) == true;

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
              child: InkWell(
                onTap: () => sph!.prefs.kv.set(_keyLesson, !lessonEnabled),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined, size: 20),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Aktuelle Stunde'),
                            SizedBox(height: 2),
                            Text(
                              'Countdown und nächste Stunde im Unterricht',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: lessonEnabled,
                        onChanged: (v) => sph!.prefs.kv.set(_keyLesson, v),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ];
      },
    );
  }
}
