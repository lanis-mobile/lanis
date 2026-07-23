import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

class ThemeRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final themeRevisionProvider = NotifierProvider<ThemeRevision, int>(
  ThemeRevision.new,
);

final themeSettingsProvider = Provider<Map<String, dynamic>>((ref) {
  ref.watch(themeRevisionProvider);
  final settings = ref.watch(sharedOverAccountSettingsProvider);
  return {
    'color': settings.getString('color') ?? 'standard',
    'theme': settings.getString('theme') ?? 'system',
    'is-amoled': settings.getBool('is-amoled') ?? false,
  };
});

void notifyThemeChanged(WidgetRef ref) {
  ref.read(themeRevisionProvider.notifier).bump();
}
