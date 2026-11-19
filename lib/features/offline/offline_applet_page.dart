import 'package:lanis/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/substitutions/substitutions_view.dart';
import 'package:lanis/applets/timetable/parent/parent_timetable_view.dart';
import 'package:lanis/applets/timetable/student/student_timetable_better_view.dart';
import 'package:lanis/generated/l10n.dart';
import 'cache_context.dart';
import 'cached_data_source.dart';

class OfflineAppletPage extends StatefulWidget {
  final OfflineCacheContext context;
  final CachedAppletHome<dynamic> home;
  const OfflineAppletPage({
    super.key,
    required this.context,
    required this.home,
  });
  @override
  State<OfflineAppletPage> createState() => _OfflineAppletPageState();
}

class _OfflineAppletPageState extends State<OfflineAppletPage> {
  CachedDataSource<TimeTable>? _timetable;
  CachedDataSource<SubstitutionPlan>? _substitutions;
  @override
  void initState() {
    super.initState();
    final cache = widget.context;
    if (widget.home.applet.appletPhpUrl == Applets.timetable.appletPhpUrl &&
        cache.account.accountType == AccountType.student) {
      _timetable = CachedDataSource(
        cacheOnly: true,
        read: () => cache.read(TimetableStudentParserCacheRequests.getHome()),
      );
    } else if (widget.home.applet.appletPhpUrl ==
        Applets.substitutions.appletPhpUrl) {
      _substitutions = CachedDataSource(
        cacheOnly: true,
        read: () async {
          final result = await cache.read(
            SubstitutionsParserCacheRequests.getHome(),
          );
          final filters =
              cache.settings.getJsonMap('vertretungsplan.php/filter') ?? {};
          final parsed = filters.map(
            (key, value) =>
                MapEntry(key, Map<String, dynamic>.from(value as Map)),
          );
          return result.map(
            (value) =>
                SubstitutionPlan.fromJson(value.toJson())..filterAll(parsed),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _timetable?.dispose();
    _substitutions?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = widget.context;
    return ProviderScope(
      overrides: [offlineCacheContextProvider.overrideWithValue(offline)],
      child: OfflineBannerLayout(
        offline: true,
        child: _timetable != null
            ? StudentTimetableBetterView(
                dataSource: _timetable,
                settings: offline.settings,
              )
            : _substitutions != null
            ? SubstitutionsView(
                dataSource: _substitutions,
                settings: offline.settings,
                accountType: offline.account.accountType,
              )
            : offline.account.accountType == AccountType.parent &&
                  widget.home.applet.appletPhpUrl ==
                      Applets.timetable.appletPhpUrl
            ? ParentTimetableView(offline: offline)
            : Scaffold(
                appBar: AppBar(),
                body: Center(
                  child: Text(
                    AppLocalizations.of(context).offlineDataUnavailable,
                  ),
                ),
              ),
      ),
    );
  }
}
