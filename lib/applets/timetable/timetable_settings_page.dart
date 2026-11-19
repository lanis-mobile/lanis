import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'parent/parent_timetable_view.dart';
import 'timetable_settings_view.dart';

class TimetableSettingsPage extends ConsumerSettingsColours {
  const TimetableSettingsPage({super.key});

  @override
  ConsumerState<TimetableSettingsPage> createState() =>
      _TimetableSettingsPageState();
}

class _TimetableSettingsPageState
    extends ConsumerSettingsColoursState<TimetableSettingsPage> {
  String? _singlePupilName;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).asData?.value;
    final type =
        session?.accountTypeOrNull ??
        ref.watch(activeAccountProvider)?.accountType;
    return SettingsPage(
      backgroundColor: backgroundColor,
      title: Text(AppLocalizations.of(context).timeTable),
      subtitle: type == AccountType.parent ? _singlePupilName : null,
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: backgroundColor,
            cardTheme: Theme.of(
              context,
            ).cardTheme.copyWith(color: foregroundColor),
          ),
          child: session == null
              ? const Center(child: CircularProgressIndicator())
              : type == AccountType.parent
              ? ParentTimetableView(
                  customize: true,
                  onSinglePupilChanged: (name) {
                    if (mounted && name != _singlePupilName) {
                      setState(() => _singlePupilName = name);
                    }
                  },
                )
              : const TimetableSettingsView(showAppBar: false),
        ),
      ],
    );
  }
}
