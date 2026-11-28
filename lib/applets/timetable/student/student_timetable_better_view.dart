import 'package:lanis/widgets/applet_app_bar_title.dart';

import 'dart:async';

import 'package:dart_date/dart_date.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/applets/timetable/student/student_timetable_item.dart';
import 'package:lanis/applets/timetable/student/timetable_helper.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';
import 'package:lanis/applets/timetable/timetable_version_button.dart';
import 'package:lanis/features/offline/cache_context.dart';
import 'package:lanis/features/offline/foreground_connection_monitor.dart';
import 'package:lanis/features/offline/session_reauth.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

final double itemHeight = 46;
final double headerHeight = 40;
final double hourWidth = 70;
final double pauseHeight = 18;

class StudentTimetableBetterView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  final AppletDataSource<TimeTable>? dataSource;
  final TypedSettings? settings;
  final AccountType? accountType;
  final PreferredSizeWidget? appBarBottom;
  final bool showAppBar;
  final String? pupilName;
  final ValueChanged<AppBar>? onAppBarChanged;
  final Future<MaybeCacheResult<TimeTable>> Function(String date)? loadVersion;
  final Future<Set<String>> Function(List<String> dates)?
  availableCachedVersionDates;
  const StudentTimetableBetterView({
    super.key,
    this.openDrawerCb,
    this.dataSource,
    this.settings,
    this.accountType,
    this.appBarBottom,
    this.showAppBar = true,
    this.pupilName,
    this.onAppBarChanged,
    this.loadVersion,
    this.availableCachedVersionDates,
  });

  @override
  ConsumerState<StudentTimetableBetterView> createState() =>
      _StudentTimetableBetterViewState();
}

class _StudentTimetableBetterViewState
    extends ConsumerState<StudentTimetableBetterView> {
  String? _selectedVersionDate;
  String? _defaultVersionDate;
  final Map<String, TimeTable> _versionPlans = {};
  final Map<String, DateTime> _versionFetchedAt = {};
  bool _versionLoading = false;
  int _versionRevision = 0;
  Set<String> _offlineCachedVersionDates = const {};
  String? _offlineVersionsSignature;
  int _offlineVersionsRevision = 0;

  bool _watchIsOffline() {
    if (ref.watch(offlineCacheContextProvider) != null) return true;
    return ref.watch(networkInterfaceAvailableProvider) == false ||
        ref.watch(connectionStatusProvider).asData?.value ==
            ConnectionStatus.disconnected;
  }

  bool _isVersionAvailableOffline(
    TimetableVersion version,
    String? displayedDate,
  ) {
    final date = version.date.trim();
    if (date.isEmpty) return false;
    if (date == _defaultVersionDate) return true;
    final activeDate = _selectedVersionDate ?? displayedDate;
    if (activeDate != null && date == activeDate) return true;
    if (_versionPlans.containsKey(date)) return true;
    return _offlineCachedVersionDates.contains(date);
  }

  void _scheduleOfflineVersionCheck({
    required bool isOffline,
    required List<TimetableVersion> versions,
  }) {
    if (!isOffline || versions.length < 2) {
      _offlineVersionsSignature = null;
      return;
    }
    final signature =
        '${_defaultVersionDate ?? ''}|${versions.map((v) => v.date).join(',')}';
    if (_offlineVersionsSignature == signature) return;
    _offlineVersionsSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshOfflineVersionAvailability(versions));
    });
  }

  Future<void> _refreshOfflineVersionAvailability(
    List<TimetableVersion> versions,
  ) async {
    final rev = ++_offlineVersionsRevision;
    final dates = [
      for (final v in versions)
        if (v.date.trim().isNotEmpty &&
            v.date.trim() != _defaultVersionDate &&
            !_versionPlans.containsKey(v.date.trim()))
          v.date.trim(),
    ];
    Set<String> cached = const {};
    if (dates.isNotEmpty) {
      try {
        final customChecker = widget.availableCachedVersionDates;
        if (customChecker != null) {
          cached = await customChecker(dates);
        } else {
          final offline = ref.read(offlineCacheContextProvider);
          final cache = offline != null
              ? offline.cache
              : ref.read(cacheServiceProvider);
          final accountId =
              offline?.account.localId ??
              ref.read(activeAccountProvider)?.localId;
          if (accountId != null) {
            final requestToDate = <CacheRequest<TimeTable>, String>{
              for (final d in dates)
                TimetableStudentParserCacheRequests.getTimetableForDate(d): d,
            };
            final available = await cache.availableRequestsFor(
              accountId: accountId,
              requests: requestToDate.keys,
            );
            cached = {for (final req in available) requestToDate[req]!};
          }
        }
      } catch (_) {}
    }
    if (!mounted || rev != _offlineVersionsRevision) return;
    setState(() {
      _offlineCachedVersionDates = cached;
    });
  }

  Future<MaybeCacheResult<TimeTable>> _fetchVersion(String date) {
    final customLoader = widget.loadVersion;
    if (customLoader != null) {
      return customLoader(date);
    }
    final isOfflineNet = ref.read(networkInterfaceAvailableProvider) == false;
    final policy = isOfflineNet
        ? CacheReadPolicy.cacheOnly
        : CacheReadPolicy.networkFirst;
    final session = isOfflineNet ? null : ref.read(sessionProvider).asData?.value;
    return runWithSessionReauth(
      session,
      () => ref
          .read(timetableParserProvider)
          .loadCachedTimetableForDate(date, policy: policy),
    );
  }

  Future<void> _selectVersion(
    TimetableVersion version, {
    bool forceRefresh = false,
  }) async {
    final date = version.date.trim();
    if (date.isEmpty) return;
    if (!forceRefresh && date == _defaultVersionDate) {
      if (_selectedVersionDate != null || _versionLoading) {
        _versionRevision++;
        setState(() {
          _selectedVersionDate = null;
          _versionLoading = false;
        });
      }
      return;
    }
    if (!forceRefresh &&
        date == _selectedVersionDate &&
        _versionPlans.containsKey(date)) {
      return;
    }

    final previousDate = _selectedVersionDate;
    final rev = ++_versionRevision;
    final hasMemory = _versionPlans.containsKey(date);
    setState(() {
      _selectedVersionDate = date;
      _versionLoading = !hasMemory || forceRefresh;
    });
    if (hasMemory && !forceRefresh) return;

    try {
      final result = await _fetchVersion(date);
      if (!mounted || rev != _versionRevision) return;
      setState(() {
        _versionPlans[date] = result.data;
        _versionFetchedAt[date] = result.fetchedAt;
        _versionLoading = false;
      });
    } catch (_) {
      if (!mounted || rev != _versionRevision) return;
      setState(() {
        _versionLoading = false;
        if (!_versionPlans.containsKey(date)) {
          _selectedVersionDate =
              (previousDate == null || _versionPlans.containsKey(previousDate))
              ? previousDate
              : null;
        }
      });
    }
  }

  AppBar? _appBar(AppBar appBar) {
    if (widget.onAppBarChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAppBarChanged?.call(appBar);
      });
    }
    return widget.showAppBar ? appBar : null;
  }

  List<TimetableDay> getSelectedPlan(
    TimeTable data,
    TimeTableType selectedType,
    Map<String, dynamic> settings,
  ) {
    List<List<TimetableSubject>>? customLessons =
        TimeTableHelper.getCustomLessons(settings);
    if (selectedType == TimeTableType.own && data.planForOwn != null) {
      return TimeTableHelper.mergeByIndices(data.planForOwn!, customLessons);
    }
    final planForAll = data.planForAll;
    if (planForAll == null) {
      return const [];
    }
    return TimeTableHelper.mergeByIndices(planForAll, customLessons);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.dataSource == null
        ? ref.watch(sessionProvider).asData?.value
        : null;
    if (session == null && widget.dataSource == null) {
      return Scaffold(
        appBar: _appBar(
          AppBar(
            title: AppletAppBarTitle(
              title: Text(timeTableDefinition.label(context)),
              subtitle: widget.appBarBottom == null ? widget.pupilName : null,
            ),
            bottom: widget.appBarBottom,
            leading: widget.openDrawerCb != null
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => widget.openDrawerCb!(),
                  )
                : null,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final accountType = widget.dataSource != null
        ? widget.accountType ?? AccountType.student
        : session?.accountTypeOrNull ??
              ref.read(activeAccountProvider)?.accountType ??
              AccountType.student;
    final AppletDataSource<TimeTable> parser =
        widget.dataSource ?? ref.watch(timetableParserProvider);
    return CombinedAppletBuilder<TimeTable>(
      parser: parser,
      settings: widget.settings,
      phpUrl: timeTableDefinition.appletPhpUrl,
      settingsDefaults: timeTableDefinition.settingsDefaults,
      accountType: accountType,
      loadingAppBar: _appBar(
        AppBar(
          title: AppletAppBarTitle(
            title: Text(timeTableDefinition.label(context)),
            subtitle: widget.appBarBottom == null ? widget.pupilName : null,
          ),
          bottom: widget.appBarBottom,
          leading: widget.openDrawerCb != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => widget.openDrawerCb!(),
                )
              : null,
        ),
      ),
      builder:
          (
            BuildContext context,
            TimeTable baseTimetable,
            _,
            Map<String, dynamic> settings,
            updateSettings,
            Future<void> Function()? refresh,
          ) {
            if (_defaultVersionDate == null &&
                baseTimetable.planDate != null &&
                baseTimetable.planDate!.isNotEmpty) {
              _defaultVersionDate = baseTimetable.planDate;
            }
            final activeDate = _selectedVersionDate;
            final timetable =
                (activeDate != null && activeDate != _defaultVersionDate)
                ? (_versionPlans[activeDate] ?? baseTimetable)
                : baseTimetable;

            Future<void> Function()? effectiveRefresh;
            if (activeDate != null && activeDate != _defaultVersionDate) {
              effectiveRefresh = () async {
                await _selectVersion(
                  TimetableVersion(date: activeDate, label: activeDate),
                  forceRefresh: true,
                );
                await refresh?.call();
              };
            } else {
              effectiveRefresh = refresh;
            }

            TimeTableType selectedType =
                settings['student-selected-type'] == 'TimeTableType.own'
                ? TimeTableType.own
                : TimeTableType.all;
            List<TimetableDay> selectedPlan = getSelectedPlan(
              timetable,
              selectedType,
              settings,
            );
            final weekSelection = TimetableWeekSelection.fromSettings(settings);
            final selectedBadge = weekSelection.resolveBadge(
              timetable.weekBadge,
            );
            final uniqueBadges = <String>{
              for (final plan in [
                timetable.planForAll,
                timetable.planForOwn,
                selectedPlan,
              ])
                for (final day in plan ?? <TimetableDay>[])
                  for (final lesson in day)
                    if (lesson.badge != null && lesson.badge!.trim().isNotEmpty)
                      lesson.badge!.trim(),
              if (timetable.weekBadge?.trim().isNotEmpty ?? false)
                timetable.weekBadge!.trim(),
              if (weekSelection.badge != null) weekSelection.badge!,
            }.toList()..sort();
            // Cached/offline badges belong to the fetched week too. Advance
            // the dates only when fresh server data supplies the new badge.
            final fetchedAt =
                (activeDate != null ? _versionFetchedAt[activeDate] : null) ??
                parser.latestResponse?.fetchedAt ??
                DateTime.now();
            final weekStart = timetableWeekStart(fetchedAt);

            TimeTableData data = TimeTableData(
              filterCalendarWeekLessons(selectedPlan, weekStart),
              timetable,
              settings,
              selectedBadge,
            );

            final showVersionPicker =
                timetable.hasMultipleVersions ||
                baseTimetable.hasMultipleVersions;
            final versions = timetable.hasMultipleVersions
                ? timetable.availableVersions
                : baseTimetable.availableVersions;
            final isOffline = _watchIsOffline();
            _scheduleOfflineVersionCheck(
              isOffline: isOffline,
              versions: versions,
            );
            final isTablet = Responsive.isTablet(context);

            final appBar = AppBar(
              title: AppletAppBarTitle(
                title: Text(timeTableDefinition.label(context)),
                subtitle: widget.appBarBottom == null ? widget.pupilName : null,
              ),
              bottom: widget.appBarBottom,
              leading: widget.openDrawerCb != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => widget.openDrawerCb!(),
                    )
                  : null,
              actions: (!showVersionPicker && data.hours.isEmpty)
                  ? null
                  : [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showVersionPicker)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: TimetableVersionButton(
                                  versions: versions,
                                  selectedDate:
                                      _selectedVersionDate ??
                                      timetable.planDate,
                                  defaultDate: _defaultVersionDate,
                                  compact: !isTablet,
                                  isVersionEnabled: isOffline
                                      ? (v) => _isVersionAvailableOffline(
                                          v,
                                          timetable.planDate,
                                        )
                                      : null,
                                  onSelected: (v) =>
                                      unawaited(_selectVersion(v)),
                                ),
                              ),
                            if (data.hours.isNotEmpty &&
                                uniqueBadges.isNotEmpty)
                              PopupMenuButton<TimetableWeekSelection>(
                                tooltip: AppLocalizations.of(context).week,
                                onSelected: (selection) => updateSettings(
                                  'student-week-selection',
                                  selection.toJson(),
                                ),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value:
                                        const TimetableWeekSelection.current(),
                                    child: Text(
                                      AppLocalizations.of(context).currentWeek,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: const TimetableWeekSelection.all(),
                                    child: Text(
                                      AppLocalizations.of(context)
                                          .timetableAllWeeks,
                                    ),
                                  ),
                                  for (final badge in uniqueBadges)
                                    PopupMenuItem(
                                      value: TimetableWeekSelection.badge(
                                        badge,
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)
                                            .timetableWeek(badge),
                                      ),
                                    ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(switch (weekSelection.mode) {
                                    TimetableWeekMode.current =>
                                      AppLocalizations.of(context).currentWeek,
                                    TimetableWeekMode.all =>
                                      AppLocalizations.of(context)
                                          .timetableAllWeeks,
                                    TimetableWeekMode.badge =>
                                      AppLocalizations.of(context)
                                          .timetableWeek(selectedBadge!),
                                  }),
                                ),
                              ),
                            if (data.hours.isNotEmpty)
                              IconButton(
                                onPressed: () => updateSettings(
                                  'single-day',
                                  !(settings['single-day'] ?? false),
                                ),
                                icon: (settings['single-day'] ?? false)
                                    ? Icon(Icons.calendar_today)
                                    : Icon(Icons.calendar_today_outlined),
                              ),
                          ],
                        ),
                      ),
                    ],
            );

            final switchPlanButton = timetable.planForOwn != null
                ? FloatingActionButton(
                    heroTag: "toggle",
                    tooltip: selectedType == TimeTableType.all
                        ? AppLocalizations.of(context).timetableSwitchToPersonal
                        : AppLocalizations.of(context).timetableSwitchToClass,
                    onPressed: () => updateSettings(
                      'student-selected-type',
                      selectedType == TimeTableType.all
                          ? 'TimeTableType.own'
                          : 'TimeTableType.all',
                    ),
                    child: Icon(
                      selectedType == TimeTableType.all
                          ? Icons.person
                          : Icons.people,
                    ),
                  )
                : null;

            if (isTimetableVisuallyEmpty(
              hoursEmpty: data.hours.isEmpty,
              daysEmpty: data.timetableDays.isEmpty,
            )) {
              return Scaffold(
                appBar: _appBar(appBar),
                floatingActionButton: switchPlanButton,
                body: Column(
                  children: [
                    if (_versionLoading)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: RefreshIndicator(
                        notificationPredicate: effectiveRefresh != null
                            ? (_) => true
                            : (_) => false,
                        onRefresh: effectiveRefresh ?? () async {},
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverFillRemaining(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Spacer(),
                                  const Icon(
                                    Icons.sentiment_dissatisfied,
                                    size: 60,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text(
                                      AppLocalizations.of(context).noEntries,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              appBar: _appBar(appBar),
              body: Column(
                children: [
                  if (_versionLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: TimeTableView(
                        data: data,
                        weekStart: weekStart,
                        timetable: timetable,
                        settings: settings,
                        updateSettings: updateSettings,
                        refresh: effectiveRefresh,
                      ),
                    ),
                  ),
                ],
              ),
              floatingActionButton: switchPlanButton,
            );
          },
    );
  }
}

class TimeTableView extends StatelessWidget {
  final TimeTableData data;
  final DateTime weekStart;
  final TimeTable timetable;
  final Map<String, dynamic> settings;
  final Function updateSettings;
  final Future<void> Function()? refresh;

  double calculateColumnHeight(List<TimeTableRow> rows) {
    double totalHeight = 0;
    for (var row in rows) {
      totalHeight +=
          (row.type == TimeTableRowType.lesson
              ? itemHeight
              : itemHeight - pauseHeight) +
          8;
    }
    return totalHeight;
  }

  const TimeTableView({
    super.key,
    required this.data,
    required this.weekStart,
    required this.timetable,
    required this.settings,
    required this.updateSettings,
    this.refresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh ?? () async {},
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Row(
                  spacing: 4.0,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      spacing: 8.0,
                      children: [
                        SizedBox(
                          height: headerHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("KW ${timetableWeekNumber(weekStart)}"),
                              if (data.weekBadge != null &&
                                  data.weekBadge!.isNotEmpty)
                                Text(
                                  AppLocalizations.of(context)
                                      .timetableWeek(data.weekBadge!),
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (var (row) in data.hours)
                          Container(
                            decoration: BoxDecoration(
                              color: row.type == TimeTableRowType.lesson
                                  ? Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                  : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            width: hourWidth,
                            height: row.type == TimeTableRowType.lesson
                                ? itemHeight
                                : pauseHeight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    row.label,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  ...(row.type == TimeTableRowType.lesson
                                      ? [
                                          Text(
                                            row.startTime.toFlutter().format(
                                              context,
                                            ),
                                            style: TextStyle(fontSize: 10),
                                          ),
                                          Text(
                                            row.endTime.toFlutter().format(
                                              context,
                                            ),
                                            style: TextStyle(fontSize: 10),
                                          ),
                                        ]
                                      : []),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          var days = _itemDays(context);

                          if (!(settings['single-day'] ?? false)) {
                            return Row(
                              spacing: 4.0,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final (i, dayWidget) in days.indexed)
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        dayWidget,
                                        TimeMarkerWidget(
                                          data: data,
                                          weekStart: weekStart,
                                          timetable: timetable,
                                          settings: settings,
                                          day: data.weekdayIndices[i],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          } else {
                            if (days.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final todayWeekday =
                                (DateTime.now().weekday - 1) % 7;
                            var initialIndex = data.weekdayIndices.indexOf(
                              todayWeekday,
                            );
                            if (initialIndex == -1) {
                              initialIndex = data.weekdayIndices.indexWhere(
                                (d) => d > todayWeekday,
                              );
                              if (initialIndex == -1) {
                                initialIndex = 0;
                              }
                            }
                            return SizedBox(
                              height: calculateColumnHeight(data.hours) + 48,
                              child: DefaultTabController(
                                length: days.length,
                                initialIndex: initialIndex,
                                child: TabBarView(
                                  children: [
                                    for (final (i, dayWidget) in days.indexed)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4.0,
                                          right: 8.0,
                                        ),
                                        child: Stack(
                                          children: [
                                            dayWidget,
                                            TimeMarkerWidget(
                                              data: data,
                                              weekStart: weekStart,
                                              timetable: timetable,
                                              settings: settings,
                                              day: data.weekdayIndices[i],
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _itemDays(BuildContext context) {
    return [
      for (int i = 0; i < data.timetableDays.length; i++)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: headerHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Builder(
                builder: (context) {
                  // Calendar construction keeps local midnight across DST changes.
                  final weekdayIndex = data.weekdayIndices[i];
                  final date = DateTime(
                    weekStart.year,
                    weekStart.month,
                    weekStart.day + weekdayIndex,
                  );

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.E(
                          Localizations.localeOf(context).languageCode,
                        ).format(date),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        date.format('dd.MM.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8.0),
            SizedBox(
              height: calculateColumnHeight(data.hours),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      for (var (index, row) in data.hours.indexed)
                        ListItem(
                          iteration: index,
                          row: row,
                          data: data,
                          timetableDays: data.timetableDays,
                          i: i,
                          width: constraints.maxWidth,
                          settings: settings,
                          updateSettings: updateSettings,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
    ];
  }
}

class TimeMarkerWidget extends ConsumerStatefulWidget {
  const TimeMarkerWidget({
    super.key,
    required this.data,
    required this.weekStart,
    required this.timetable,
    required this.settings,
    this.day,
  });

  final TimeTableData data;
  final DateTime weekStart;
  final TimeTable timetable;
  final Map<String, dynamic> settings;
  final int? day;

  @override
  ConsumerState<TimeMarkerWidget> createState() => _TimeMarkerWidgetState();
}

class _TimeMarkerWidgetState extends ConsumerState<TimeMarkerWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final int msUntilNextMinute = (60 - now.second) * 1000 - now.millisecond;
    _timer = Timer(Duration(milliseconds: msUntilNextMinute), () {
      if (mounted) setState(() {});
      _timer = Timer.periodic(Duration(minutes: 1), (timer) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double offset = 8;
    final now = DateTime.now();
    if (timetableWeekStart(now) != widget.weekStart ||
        (widget.data.weekBadge != null &&
            widget.data.weekBadge != widget.timetable.weekBadge)) {
      return const SizedBox.shrink();
    }
    final nowTod = SphTimeOfDay(hour: now.hour, minute: now.minute);

    // Current day 0 Monday, 6 Sunday
    var currentDay = (DateTime.now().weekday - 1) % 7;

    if (currentDay != widget.day) {
      return SizedBox();
    }

    if (widget.data.hours.isEmpty || widget.data.timetableDays.isEmpty) {
      return const SizedBox();
    }

    if (nowTod < widget.data.hours.first.startTime) {
      return SizedBox();
    }

    if (nowTod > widget.data.hours.last.endTime) {
      return SizedBox();
    }

    for (var (lesson) in widget.data.hours) {
      // Check if lesson is already over and add the height of the lesson (or height of break)
      // If in the lesson add percentage of the lesson that has already passed
      final height = lesson.type == TimeTableRowType.lesson
          ? itemHeight
          : pauseHeight;
      if (nowTod >= lesson.startTime && nowTod <= lesson.endTime) {
        final diff =
            height *
            ((-nowTod.differenceInMinutes(lesson.startTime)) /
                lesson.startTime.differenceInMinutes(lesson.endTime));
        offset += diff;

        break;
      } else if (nowTod > lesson.endTime) {
        offset += height + 8;
      }
    }

    // Padding for the sidebar
    final barWidth = hourWidth + 4;
    final wholeWidth = (MediaQuery.of(context).size.width - barWidth - 10);
    final dayWidth = wholeWidth / widget.data.timetableDays.length;

    const double lineHeight = 2;
    return Positioned(
      top: headerHeight + offset - (lineHeight / 2),
      child: Container(
        color: Colors.red,
        width: (widget.settings['single-day'] ?? false)
            ? wholeWidth - 10
            : dayWidth,
        height: lineHeight,
      ),
    );
  }
}
