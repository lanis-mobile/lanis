import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

const kNavRailShowMoodleKey = 'nav-rail-show-moodle';
const kNavRailShowOpenBrowserKey = 'nav-rail-show-open-browser';

class NavRailRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final navRailRevisionProvider = NotifierProvider<NavRailRevision, int>(
  NavRailRevision.new,
);

class NavRailSettings {
  final bool showMoodle;
  final bool showOpenBrowser;

  const NavRailSettings({
    required this.showMoodle,
    required this.showOpenBrowser,
  });
}

final navRailSettingsProvider = Provider<NavRailSettings>((ref) {
  ref.watch(navRailRevisionProvider);
  final shared = ref.watch(sharedOverAccountSettingsProvider);
  return NavRailSettings(
    showMoodle: shared.getBool(kNavRailShowMoodleKey) ?? false,
    showOpenBrowser: shared.getBool(kNavRailShowOpenBrowserKey) ?? false,
  );
});

void notifyNavRailSettingsChanged(WidgetRef ref) {
  ref.read(navRailRevisionProvider.notifier).bump();
}
