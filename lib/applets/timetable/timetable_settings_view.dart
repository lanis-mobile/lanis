import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'definition.dart';
import 'timetable_modifications_editor.dart';

/// The same editor and data-source adapter for student and parent timetables.
class TimetableSettingsView extends ConsumerStatefulWidget {
  final AppletDataSource<TimeTable>? dataSource;
  final TypedSettings? settings;
  final AccountType accountType;
  final PreferredSizeWidget? appBarBottom;
  final bool showAppBar;
  final ValueChanged<AppBar>? onAppBarChanged;
  const TimetableSettingsView({
    super.key,
    this.dataSource,
    this.settings,
    this.accountType = AccountType.student,
    this.appBarBottom,
    this.showAppBar = true,
    this.onAppBarChanged,
  });
  @override
  ConsumerState<TimetableSettingsView> createState() =>
      _TimetableSettingsViewState();
}

class _TimetableSettingsViewState extends ConsumerState<TimetableSettingsView> {
  @override
  Widget build(BuildContext context) {
    final header = AppBar(
      toolbarHeight: 0,
      primary: false,
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      bottom: widget.appBarBottom,
    );
    if (widget.onAppBarChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAppBarChanged?.call(header);
      });
    }
    return CombinedAppletBuilder<TimeTable>(
      parser: widget.dataSource ?? ref.watch(timetableParserProvider),
      settings: widget.settings,
      phpUrl: timeTableDefinition.appletPhpUrl,
      settingsDefaults: timeTableDefinition.settingsDefaults,
      accountType: widget.accountType,
      loadingAppBar: widget.showAppBar ? header : null,
      builder: (context, timetable, type, settings, updateSetting, refresh) =>
          Scaffold(
            appBar: widget.showAppBar ? header : null,
            body: TimetableModificationsEditor(
              timetable: timetable,
              settings: settings,
              updateSettings: updateSetting,
            ),
          ),
    );
  }
}
