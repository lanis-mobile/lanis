import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/timetable/definition.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';
import 'package:lanis/applets/timetable/teacher/teacher_timetable_grid.dart';
import 'package:lanis/applets/timetable/teacher/teacher_timetable_models.dart';
import 'package:lanis/applets/timetable/teacher/teacher_timetable_panels.dart';
import 'package:lanis/applets/timetable/timetable_version_button.dart';
import 'package:lanis/features/offline/cache_context.dart';
import 'package:lanis/features/offline/cached_data_source.dart';
import 'package:lanis/features/offline/foreground_connection_monitor.dart';
import 'package:lanis/features/offline/session_reauth.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/utils/root_nav.dart';
import 'package:lanis/widgets/applet_app_bar_title.dart';
import 'package:lanis/widgets/error_view.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

enum _TabletRightMode { none, details, freeRooms }

/// Teacher timetable view implementing:
/// - Phone: Native Lanis extension (Own Plan + AppBar actions + FAB Plan Switcher)
/// - Tablet: 1B-2 3-pane view (collapsible left plan catalog · center Lanis grid ·
///   on-demand right pane for lesson details or live Free Rooms search)
class TeacherTimetableView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  final OfflineCacheContext? offline;

  const TeacherTimetableView({super.key, this.openDrawerCb, this.offline});

  @override
  ConsumerState<TeacherTimetableView> createState() =>
      _TeacherTimetableViewState();
}

class _TeacherTimetableViewState extends ConsumerState<TeacherTimetableView>
    with WidgetsBindingObserver {
  late final CachedDataSource<TeacherTimetableOverview> _overviewSource;

  TeacherTimetableTarget? _activeTarget;
  String? _ownTeacherId;
  String? _selectedVersionDate;
  String? _defaultVersionDate;
  final Map<String, TeacherTimetablePlan> _loadedPlans = {};
  final Map<String, DateTime> _planFetchedAt = {};
  TeacherTimetablePlan? _lastDisplayedPlan;
  bool _planLoading = false;
  Object? _planError;
  StackTrace? _planStackTrace;
  int _planRevision = 0;

  // UI view state
  bool _singleDayPhone = false;
  _TabletRightMode _tabletRightMode = _TabletRightMode.none;
  _TabletRightMode _lastRightMode = _TabletRightMode.none;
  TeacherEntrySelection? _selectedEntry;
  TeacherEntrySelection? _lastSelectedEntry;
  TeacherTimetablePlan? _lastSelectedPlan;
  TimetableWeekSelection _weekSelection = const TimetableWeekSelection.all();
  final Set<TeacherTimetableCategory> _expandedCategories = {
    TeacherTimetableCategory.teacher,
    TeacherTimetableCategory.room,
  };
  List<String> _recentTargetKeys = const [];
  static const String _recentTargetsSettingsKey =
      'stundenplan.php/teacher-recent';
  static const int _maxRecentTargets = 3;

  // Free rooms state
  int _freeRoomsWeekday = DateTime.now().weekday.clamp(1, 5);
  List<int> _freeRoomsHours = const [1];
  List<int> _freeRoomsAvailableHours = const [1, 2, 3, 4, 5, 6, 7, 8];
  List<TeacherTimetableReference> _freeRoomsList = const [];
  bool _freeRoomsInitialized = false;
  bool _freeRoomsLoading = false;
  Object? _freeRoomsError;
  int _freeRoomsRevision = 0;
  final ValueNotifier<int> _freeRoomsNotifier = ValueNotifier<int>(0);

  // Offline availability state (tracks which catalog targets & versions are cached)
  Set<String> _offlineCachedTargetKeys = const {};
  Set<String> _offlineCachedVersionDates = const {};
  String? _offlineCatalogSignature;
  String? _offlineVersionsSignature;
  int _offlineCatalogRevision = 0;
  int _offlineVersionsRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final savedRecents = _settings?.getJsonList(_recentTargetsSettingsKey);
    if (savedRecents != null) {
      _recentTargetKeys = savedRecents.whereType<String>().take(
        _maxRecentTargets,
      ).toList();
    }
    _overviewSource = CachedDataSource(
      read: _readOverview,
      readCache: _readCachedOverview,
      cacheOnly: widget.offline != null,
      refreshInterval: Applets.timetable.refreshInterval,
    );
    unawaited(_overviewSource.fetchData());
  }

  TypedSettings? get _settings =>
      widget.offline?.settings ?? ref.read(accountSpecificSettingsProvider);

  void _recordRecentTarget(TeacherTimetableTarget target) {
    if (target.isOwn) return;
    final next = [
      target.key,
      for (final k in _recentTargetKeys)
        if (k != target.key) k,
    ].take(_maxRecentTargets).toList();
    _recentTargetKeys = next;
    _settings?.setJsonList(_recentTargetsSettingsKey, next);
  }

  List<TeacherTimetableTarget> _resolveRecentTargets(
    TeacherTimetableOverview overview,
  ) {
    if (_recentTargetKeys.isEmpty) return const [];
    final byKey = <String, TeacherTimetableTarget>{};
    final ownIdLower = _ownTeacherId?.trim().toLowerCase();
    for (final list in [
      overview.teachers,
      overview.classes,
      overview.rooms,
      overview.breakSupervisions,
    ]) {
      for (final ref in list) {
        if (ref.category == TeacherTimetableCategory.teacher &&
            ownIdLower != null &&
            ownIdLower.isNotEmpty &&
            ref.id.trim().toLowerCase() == ownIdLower) {
          continue;
        }
        final t = TeacherTimetableTarget(reference: ref);
        byKey[t.key] = t;
      }
    }
    return [
      for (final key in _recentTargetKeys)
        if (byKey.containsKey(key)) byKey[key]!,
    ];
  }

  void _toggleCatalogCategory(TeacherTimetableCategory category) {
    setState(() {
      if (!_expandedCategories.remove(category)) {
        _expandedCategories.add(category);
      }
    });
  }

  CacheService get _cache {
    final offline = widget.offline;
    return offline != null ? offline.cache : ref.read(cacheServiceProvider);
  }

  int get _accountId =>
      widget.offline?.account.localId ??
      ref.read(activeAccountProvider)!.localId;

  bool get _isOfflineNow =>
      widget.offline != null ||
      ref.read(networkInterfaceAvailableProvider) == false ||
      ref.read(connectionStatusProvider).asData?.value ==
          ConnectionStatus.disconnected;

  bool _watchIsOffline() =>
      widget.offline != null ||
      ref.watch(networkInterfaceAvailableProvider) == false ||
      ref.watch(connectionStatusProvider).asData?.value ==
          ConnectionStatus.disconnected;

  bool _isTargetAvailableOffline(TeacherTimetableTarget target) {
    if (target == _activeTarget && _planForTarget(target) != null) return true;
    final cacheKey = _planCacheKey(target, _selectedVersionDate);
    if (_loadedPlans.containsKey(cacheKey)) return true;
    return _offlineCachedTargetKeys.contains(target.key);
  }

  bool _isVersionAvailableOffline(TimetableVersion version) {
    final activeTarget = _activeTarget;
    final activePlan = _planForTarget(activeTarget);
    final currentDate = _selectedVersionDate ?? activePlan?.planDate;
    if (currentDate != null && version.date == currentDate) return true;
    if (activeTarget != null &&
        _loadedPlans.containsKey(_planCacheKey(activeTarget, version.date))) {
      return true;
    }
    return _offlineCachedVersionDates.contains(version.date);
  }

  void _scheduleOfflineAvailabilityCheck({
    required bool isOffline,
    required TeacherTimetableOverview overview,
    required TeacherTimetableTarget? ownTarget,
    required TeacherTimetablePlan? activePlan,
  }) {
    if (!isOffline) {
      _offlineCatalogSignature = null;
      _offlineVersionsSignature = null;
      return;
    }

    final catalogSignature =
        '${identityHashCode(overview)}|${ownTarget?.key}|'
        '${_selectedVersionDate ?? ''}|${_defaultVersionDate ?? ''}';
    if (_offlineCatalogSignature != catalogSignature) {
      _offlineCatalogSignature = catalogSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _refreshOfflineCatalogAvailability(
            overview: overview,
            ownTarget: ownTarget,
          ),
        );
      });
    }

    final activeTarget = _activeTarget;
    final versions = activePlan?.availableVersions ?? const <TimetableVersion>[];
    final versionsSignature =
        '${activeTarget?.key}|${_defaultVersionDate ?? ''}|'
        '${versions.map((v) => v.date).join(',')}';
    if (_offlineVersionsSignature != versionsSignature) {
      _offlineVersionsSignature = versionsSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _refreshOfflineVersionAvailability(
            activeTarget: activeTarget,
            versions: versions,
          ),
        );
      });
    }
  }

  Future<void> _refreshOfflineCatalogAvailability({
    required TeacherTimetableOverview overview,
    required TeacherTimetableTarget? ownTarget,
  }) async {
    final rev = ++_offlineCatalogRevision;
    final versionDate = _selectedVersionDate;
    final targets = <TeacherTimetableTarget>[
      ?ownTarget,
      for (final ref in overview.teachers)
        TeacherTimetableTarget(reference: ref),
      for (final ref in overview.classes)
        TeacherTimetableTarget(reference: ref),
      for (final ref in overview.rooms) TeacherTimetableTarget(reference: ref),
      for (final ref in overview.breakSupervisions)
        TeacherTimetableTarget(reference: ref),
    ];

    final cachedTargets = <String>{};
    final requestToTargets =
        <CacheRequest<TeacherTimetablePlan>, List<TeacherTimetableTarget>>{};
    for (final target in targets) {
      if (_loadedPlans.containsKey(_planCacheKey(target, versionDate))) {
        cachedTargets.add(target.key);
        continue;
      }
      final request = TimetableTeacherParserCacheRequests.getTimetable(
        _referenceForTarget(target, versionDate),
      );
      requestToTargets.putIfAbsent(request, () => []).add(target);
    }

    if (requestToTargets.isNotEmpty) {
      try {
        final available = await _cache.availableRequestsFor(
          accountId: _accountId,
          requests: requestToTargets.keys,
        );
        for (final req in available) {
          for (final target in requestToTargets[req]!) {
            cachedTargets.add(target.key);
          }
        }
      } catch (_) {}
    }

    if (!mounted || rev != _offlineCatalogRevision) return;
    setState(() {
      _offlineCachedTargetKeys = cachedTargets;
    });
  }

  Future<void> _refreshOfflineVersionAvailability({
    required TeacherTimetableTarget? activeTarget,
    required List<TimetableVersion> versions,
  }) async {
    final rev = ++_offlineVersionsRevision;
    final cachedVersions = <String>{};
    if (activeTarget != null && versions.length >= 2) {
      final requestToDate = <CacheRequest<TeacherTimetablePlan>, String>{};
      for (final version in versions) {
        final vDate = version.date.trim();
        if (vDate.isEmpty) continue;
        if (_loadedPlans.containsKey(_planCacheKey(activeTarget, vDate))) {
          cachedVersions.add(vDate);
          continue;
        }
        final request = TimetableTeacherParserCacheRequests.getTimetable(
          _referenceForTarget(activeTarget, vDate),
        );
        requestToDate[request] = vDate;
      }
      if (requestToDate.isNotEmpty) {
        try {
          final available = await _cache.availableRequestsFor(
            accountId: _accountId,
            requests: requestToDate.keys,
          );
          for (final req in available) {
            cachedVersions.add(requestToDate[req]!);
          }
        } catch (_) {}
      }
    }

    if (!mounted || rev != _offlineVersionsRevision) return;
    setState(() {
      _offlineCachedVersionDates = cachedVersions;
    });
  }

  Future<MaybeCacheResult<TeacherTimetableOverview>> _readCachedOverview() =>
      _cache.readCacheFor(
        accountId: _accountId,
        request: TimetableTeacherParserCacheRequests.getHome(),
      );

  Future<MaybeCacheResult<TeacherTimetableOverview>> _readOverview() {
    final offline = widget.offline;
    if (offline != null) {
      return offline.read(TimetableTeacherParserCacheRequests.getHome());
    }
    final isOfflineNet = ref.read(networkInterfaceAvailableProvider) == false;
    final policy = isOfflineNet
        ? CacheReadPolicy.cacheOnly
        : CacheReadPolicy.networkFirst;
    final session = isOfflineNet ? null : ref.read(sessionProvider).asData?.value;
    return runWithSessionReauth(
      session,
      () => ref
          .read(timetableTeacherParserProvider)
          .cached
          .getHome(cachePolicy: policy),
    );
  }

  Future<MaybeCacheResult<TeacherTimetablePlan>> _readPlan(
    TeacherTimetableReference reference, {
    bool forceRefresh = false,
  }) {
    final offline = widget.offline;
    if (offline != null) {
      return _cache.readCacheFor(
        accountId: _accountId,
        request: TimetableTeacherParserCacheRequests.getTimetable(reference),
      );
    }
    final isOfflineNet = ref.read(networkInterfaceAvailableProvider) == false;
    final policy = isOfflineNet
        ? CacheReadPolicy.cacheOnly
        : CacheReadPolicy.networkFirst;
    final session = isOfflineNet ? null : ref.read(sessionProvider).asData?.value;
    return runWithSessionReauth(
      session,
      () => ref
          .read(timetableTeacherParserProvider)
          .cached
          .getTimetable(reference, cachePolicy: policy),
    );
  }

  Future<MaybeCacheResult<TeacherTimetablePlan>?> _tryReadCachedPlan(
    TeacherTimetableReference reference,
  ) async {
    try {
      return await _cache.readCacheFor(
        accountId: _accountId,
        request: TimetableTeacherParserCacheRequests.getTimetable(reference),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.valuesOf(context).enabled) {
      _overviewSource.startAutoRefresh();
    } else {
      _overviewSource.stopAutoRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        TickerMode.valuesOf(context).enabled) {
      _overviewSource.startAutoRefresh();
      unawaited(_overviewSource.fetchData(forceRefresh: true));
      final target = _activeTarget;
      if (target != null && widget.offline == null) {
        unawaited(_selectTarget(target, forceRefresh: true));
      }
    } else {
      _overviewSource.stopAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _freeRoomsNotifier.dispose();
    _overviewSource.dispose();
    super.dispose();
  }

  TeacherTimetableTarget? _buildOwnTarget(
    TeacherTimetableOverview overview,
    String ownLabel,
  ) {
    final url = overview.ownTimetableUrl;
    if (url == null) return null;
    return TeacherTimetableTarget(
      isOwn: true,
      reference: TeacherTimetableReference(
        category: TeacherTimetableCategory.teacher,
        id: '',
        label: ownLabel,
        url: url,
      ),
    );
  }

  TeacherTimetableTarget? _defaultTargetFor(
    TeacherTimetableOverview overview,
    String ownLabel,
  ) {
    final own = _buildOwnTarget(overview, ownLabel);
    if (own != null) return own;
    if (overview.teachers.isNotEmpty) {
      return TeacherTimetableTarget(reference: overview.teachers.first);
    }
    if (overview.classes.isNotEmpty) {
      return TeacherTimetableTarget(reference: overview.classes.first);
    }
    if (overview.rooms.isNotEmpty) {
      return TeacherTimetableTarget(reference: overview.rooms.first);
    }
    if (overview.breakSupervisions.isNotEmpty) {
      return TeacherTimetableTarget(
        reference: overview.breakSupervisions.first,
      );
    }
    return null;
  }

  void _ensureInitialTargetLoaded(
    TeacherTimetableOverview overview,
    String ownLabel,
  ) {
    if (_activeTarget != null) return;
    final initial = _defaultTargetFor(overview, ownLabel);
    if (initial == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeTarget != null) return;
      unawaited(_selectTarget(initial));
    });
  }

  String _planCacheKey(TeacherTimetableTarget target, [String? versionDate]) =>
      '${target.key}@${(versionDate != null && versionDate.isNotEmpty) ? versionDate : 'default'}';

  TeacherTimetableReference _referenceForTarget(
    TeacherTimetableTarget target, [
    String? versionDate,
  ]) => (versionDate != null &&
          versionDate.isNotEmpty &&
          versionDate != _defaultVersionDate)
      ? target.reference.withDate(versionDate)
      : target.reference;

  TeacherTimetablePlan? _planForTarget(TeacherTimetableTarget? target) {
    if (target == null) return null;
    final exact = _loadedPlans[_planCacheKey(target, _selectedVersionDate)];
    if (exact != null) return exact;
    if (_planLoading && _lastDisplayedPlan != null) {
      return _lastDisplayedPlan;
    }
    return null;
  }

  DateTime? _fetchedAtForTarget(TeacherTimetableTarget? target) {
    if (target == null) return null;
    return _planFetchedAt[_planCacheKey(target, _selectedVersionDate)] ??
        _planFetchedAt[_planCacheKey(target)];
  }

  void _onSelectVersion(TimetableVersion version) {
    final target = _activeTarget;
    if (target == null) return;
    final nextDate = version.date.trim();
    if (nextDate.isEmpty || nextDate == _selectedVersionDate) return;
    setState(() {
      _selectedVersionDate = nextDate;
    });
    unawaited(
      _selectTarget(
        target,
        preserveFreeRoomsPane: _tabletRightMode == _TabletRightMode.freeRooms,
      ),
    );
  }

  Future<void> _selectTarget(
    TeacherTimetableTarget target, {
    bool forceRefresh = false,
    bool preserveFreeRoomsPane = false,
  }) async {
    final rev = ++_planRevision;
    final versionDate = _selectedVersionDate;
    final cacheKey = _planCacheKey(target, versionDate);
    final requestRef = _referenceForTarget(target, versionDate);
    final alreadyLoaded = _loadedPlans[cacheKey];

    setState(() {
      final previousTarget = _activeTarget;
      if (previousTarget != null) {
        final prevPlan = _loadedPlans[_planCacheKey(previousTarget, versionDate)];
        if (prevPlan != null) {
          _lastDisplayedPlan = prevPlan;
        }
      }
      _activeTarget = target;
      _recordRecentTarget(target);
      if (!target.isOwn) {
        _expandedCategories.add(target.category);
      }
      _planError = null;
      _planStackTrace = null;
      _selectedEntry = null;
      if (!preserveFreeRoomsPane &&
          _tabletRightMode == _TabletRightMode.details) {
        _tabletRightMode = _TabletRightMode.none;
      }
      _planLoading = alreadyLoaded == null || forceRefresh;
      if (alreadyLoaded != null) {
        _lastDisplayedPlan = alreadyLoaded;
        _validateWeekSelectionFor(alreadyLoaded);
      }
    });

    if (alreadyLoaded != null && !forceRefresh) {
      return;
    }

    if (alreadyLoaded == null && !forceRefresh) {
      final cached = await _tryReadCachedPlan(requestRef);
      if (mounted && rev == _planRevision && cached != null) {
        setState(() {
          _loadedPlans[cacheKey] = cached.data;
          _planFetchedAt[cacheKey] = cached.fetchedAt;
          if (versionDate == null &&
              cached.data.planDate != null &&
              cached.data.planDate!.isNotEmpty) {
            _defaultVersionDate ??= cached.data.planDate;
            _loadedPlans[_planCacheKey(target, cached.data.planDate)] =
                cached.data;
            _planFetchedAt[_planCacheKey(target, cached.data.planDate)] =
                cached.fetchedAt;
          }
          _lastDisplayedPlan = cached.data;
          if (target.isOwn && cached.data.targetId.isNotEmpty) {
            _ownTeacherId = cached.data.targetId;
          }
          _planLoading = false;
        });
      }
    }

    try {
      final result = await _readPlan(
        requestRef,
        forceRefresh: forceRefresh,
      );
      if (!mounted || rev != _planRevision) return;
      setState(() {
        _loadedPlans[cacheKey] = result.data;
        _planFetchedAt[cacheKey] = result.fetchedAt;
        if (versionDate == null &&
            result.data.planDate != null &&
            result.data.planDate!.isNotEmpty) {
          _defaultVersionDate ??= result.data.planDate;
          _loadedPlans[_planCacheKey(target, result.data.planDate)] =
              result.data;
          _planFetchedAt[_planCacheKey(target, result.data.planDate)] =
              result.fetchedAt;
        }
        _lastDisplayedPlan = result.data;
        if (target.isOwn && result.data.targetId.isNotEmpty) {
          _ownTeacherId = result.data.targetId;
        }
        _validateWeekSelectionFor(result.data);
        _planLoading = false;
        _planError = null;
        _planStackTrace = null;
      });
    } catch (error, stack) {
      if (!mounted || rev != _planRevision) return;
      setState(() {
        _planLoading = false;
        if (!_loadedPlans.containsKey(cacheKey)) {
          _planError = error;
          _planStackTrace = stack;
        }
      });
    }
  }

  Future<void> _refreshAll() async {
    await _overviewSource.fetchData(forceRefresh: true);
    final active = _activeTarget;
    if (active != null) {
      await _selectTarget(active, forceRefresh: true);
    }
  }

  Future<void> _loadFreeRooms({
    bool useServerDefaults = false,
    int? weekday,
    List<int>? hours,
  }) async {
    if (_isOfflineNow) {
      _updateFreeRoomsState(() {
        _freeRoomsLoading = false;
        _freeRoomsError = AppLocalizations.of(context).offlineDataUnavailable;
      });
      return;
    }

    final rev = ++_freeRoomsRevision;
    _updateFreeRoomsState(() {
      _freeRoomsLoading = true;
      _freeRoomsError = null;
      if (weekday != null) _freeRoomsWeekday = weekday;
      if (hours != null) _freeRoomsHours = hours;
    });

    final effectiveHours = hours ?? _freeRoomsHours;
    if (!useServerDefaults && effectiveHours.isEmpty) {
      _updateFreeRoomsState(() {
        _freeRoomsLoading = false;
        _freeRoomsList = const [];
      });
      return;
    }

    try {
      final parser = ref.read(timetableTeacherParserProvider);
      final session = ref.read(sessionProvider).asData?.value;
      final result = await runWithSessionReauth(
        session,
        () => useServerDefaults
            ? parser.getFreeRooms()
            : parser.getFreeRooms(
                weekday: weekday ?? _freeRoomsWeekday,
                hours: effectiveHours,
              ),
      );
      if (!mounted || rev != _freeRoomsRevision) return;
      _updateFreeRoomsState(() {
        _freeRoomsInitialized = true;
        _freeRoomsLoading = false;
        _freeRoomsError = null;
        _freeRoomsWeekday = result.weekday.clamp(1, 5);
        _freeRoomsSelectedHoursFromServer(result);
        _freeRoomsList = result.rooms;
      });
    } catch (error) {
      if (!mounted || rev != _freeRoomsRevision) return;
      _updateFreeRoomsState(() {
        _freeRoomsLoading = false;
        _freeRoomsError = error;
      });
    }
  }

  void _freeRoomsSelectedHoursFromServer(TeacherFreeRoomsResult result) {
    if (result.availableHours.isNotEmpty) {
      _freeRoomsAvailableHours = result.availableHours;
    }
    if (result.selectedHours.isNotEmpty) {
      _freeRoomsHours = result.selectedHours;
    }
  }

  void _validateWeekSelectionFor(TeacherTimetablePlan plan) {
    if (_weekSelection.mode == TimetableWeekMode.badge) {
      final badges = collectTeacherWeekBadges(plan);
      final selected = _weekSelection.resolveBadge(plan.weekBadge);
      if (selected == null || !badges.contains(selected)) {
        _weekSelection = const TimetableWeekSelection.all();
      }
    }
  }

  void _updateFreeRoomsState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _freeRoomsNotifier.value++;
  }

  void _onSelectFreeRoomWeekday(int day) {
    unawaited(_loadFreeRooms(weekday: day, hours: _freeRoomsHours));
  }

  void _onToggleFreeRoomHour(int hour) {
    final next = List<int>.from(_freeRoomsHours);
    if (next.contains(hour)) {
      if (next.length <= 1) return;
      next.remove(hour);
    } else {
      next.add(hour);
      next.sort();
    }
    unawaited(_loadFreeRooms(weekday: _freeRoomsWeekday, hours: next));
  }

  void _openPhonePlanSwitcher(
    BuildContext context,
    TeacherTimetableOverview overview,
    TeacherTimetableTarget? ownTarget, {
    required bool isOffline,
  }) {
    showRootModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
            final maxHeight = math.max(
              160.0,
              (MediaQuery.sizeOf(context).height - viewInsets) * 0.78,
            );
            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: TeacherPlanCatalogPanel(
                  overview: overview,
                  ownTarget: ownTarget,
                  ownTeacherId: _ownTeacherId,
                  activeTarget: _activeTarget,
                  recentTargets: _resolveRecentTargets(overview),
                  expandedCategories: _expandedCategories,
                  isTargetEnabled: isOffline ? _isTargetAvailableOffline : null,
                  onToggleCategory: (category) {
                    _toggleCatalogCategory(category);
                    setSheetState(() {});
                  },
                  onSelectTarget: (target) {
                    Navigator.of(sheetCtx).pop();
                    unawaited(_selectTarget(target));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openPhoneFreeRoomsSheet(BuildContext context) {
    if (_isOfflineNow) return;
    if (!_freeRoomsInitialized && !_freeRoomsLoading) {
      unawaited(_loadFreeRooms(useServerDefaults: true));
    }
    showRootModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return ListenableBuilder(
          listenable: _freeRoomsNotifier,
          builder: (context, _) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(
                  160.0,
                  MediaQuery.sizeOf(context).height * 0.78,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).teacherTimetableFreeRooms,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: TeacherFreeRoomsPanel(
                      weekday: _freeRoomsWeekday,
                      selectedHours: _freeRoomsHours,
                      availableHours: _freeRoomsAvailableHours,
                      rooms: _freeRoomsList,
                      loading: _freeRoomsLoading,
                      error: _freeRoomsError,
                      isTabletPane: false,
                      onSelectWeekday: _onSelectFreeRoomWeekday,
                      onToggleHour: _onToggleFreeRoomHour,
                      onRetry: () => _loadFreeRooms(
                        useServerDefaults: !_freeRoomsInitialized,
                      ),
                      onOpenRoom: (target) {
                        Navigator.of(sheetCtx).pop();
                        unawaited(_selectTarget(target));
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openPhoneEntrySheet(
    BuildContext context, {
    required TeacherTimetablePlan plan,
    required TeacherTimetableOverview overview,
    required int dayColumnIndex,
    required TeacherTimetableEntry initialEntry,
    required DateTime weekStart,
  }) {
    var current = TeacherEntrySelection(
      dayColumnIndex: dayColumnIndex,
      entry: initialEntry,
    );
    showRootModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              child: TeacherEntryInspectorPanel(
                plan: plan,
                overview: overview,
                selection: current,
                weekStart: weekStart,
                isTargetEnabled: _isOfflineNow
                    ? _isTargetAvailableOffline
                    : null,
                isOffline: _isOfflineNow,
                onSelectSibling: (sib) => setSheetState(
                  () => current = TeacherEntrySelection(
                    dayColumnIndex: dayColumnIndex,
                    entry: sib,
                  ),
                ),
                onOpenTarget: (target) {
                  Navigator.of(sheetCtx).pop();
                  unawaited(_selectTarget(target));
                },
              ),
            );
          },
        );
      },
    );
  }

  void _handleTabletSelectEntry(
    int dayColumnIndex,
    TeacherTimetableEntry entry,
  ) {
    final next = TeacherEntrySelection(
      dayColumnIndex: dayColumnIndex,
      entry: entry,
    );
    final activePlan = _planForTarget(_activeTarget);
    setState(() {
      if (_tabletRightMode == _TabletRightMode.details &&
          _selectedEntry == next) {
        _tabletRightMode = _TabletRightMode.none;
        _selectedEntry = null;
      } else {
        _selectedEntry = next;
        _lastSelectedEntry = next;
        _lastSelectedPlan = activePlan;
        _tabletRightMode = _TabletRightMode.details;
        _lastRightMode = _TabletRightMode.details;
      }
    });
  }

  void _toggleTabletFreeRooms() {
    var shouldLoad = false;
    setState(() {
      if (_tabletRightMode == _TabletRightMode.freeRooms) {
        _tabletRightMode = _TabletRightMode.none;
      } else {
        _tabletRightMode = _TabletRightMode.freeRooms;
        _lastRightMode = _TabletRightMode.freeRooms;
        _selectedEntry = null;
        shouldLoad = !_freeRoomsInitialized && !_freeRoomsLoading;
      }
    });
    if (shouldLoad) {
      unawaited(_loadFreeRooms(useServerDefaults: true));
    }
  }

  Widget _buildWeekBadgeAction(
    BuildContext context,
    TeacherTimetablePlan plan,
  ) {
    final badges = collectTeacherWeekBadges(plan);
    if (badges.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final resolvedBadge = _weekSelection.resolveBadge(plan.weekBadge);
    final label = switch (_weekSelection.mode) {
      TimetableWeekMode.current =>
        resolvedBadge != null
            ? l10n.timetableWeek(resolvedBadge)
            : l10n.currentWeek,
      TimetableWeekMode.all => l10n.timetableAllWeeks,
      TimetableWeekMode.badge => l10n.timetableWeek(
        resolvedBadge ?? badges.first,
      ),
    };

    return PopupMenuButton<TimetableWeekSelection>(
      tooltip: l10n.week,
      onSelected: (sel) => setState(() => _weekSelection = sel),
      itemBuilder: (context) => [
        if (plan.weekBadge != null && plan.weekBadge!.trim().isNotEmpty)
          PopupMenuItem(
            value: const TimetableWeekSelection.current(),
            child: Text(l10n.currentWeek),
          ),
        PopupMenuItem(
          value: const TimetableWeekSelection.all(),
          child: Text(l10n.timetableAllWeeks),
        ),
        for (final badge in badges)
          PopupMenuItem(
            value: TimetableWeekSelection.badge(badge),
            child: Text(l10n.timetableWeek(badge)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanBody({
    required BuildContext context,
    required TeacherTimetableOverview overview,
    required bool isTablet,
    required bool compactGrid,
  }) {
    final target = _activeTarget;
    final plan = _planForTarget(target);

    if (_planError != null && plan == null) {
      final err = _planError;
      if (err is CacheUnavailableException) {
        return const OfflineDataUnavailableView();
      }
      return AppletErrorView(
        error: err is Exception ? err : UnknownException(err.toString()),
        stack: _planStackTrace,
        retry: target == null
            ? _refreshAll
            : () => _selectTarget(target, forceRefresh: true),
      );
    }

    if (plan == null) {
      final hasAnyTarget =
          _defaultTargetFor(
            overview,
            AppLocalizations.of(context).teacherTimetableOwnPlan,
          ) !=
          null;
      if (target == null && !hasAnyTarget) {
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_busy_outlined, size: 52),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context).noEntries,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final fetchedAt = _fetchedAtForTarget(target) ?? DateTime.now();
    final weekStart = timetableWeekStart(fetchedAt);
    final effectiveBadge = _weekSelection.resolveBadge(plan.weekBadge);

    return Column(
      children: [
        if (_planLoading) const LinearProgressIndicator(minHeight: 2),
        TeacherPlanContextBanner(plan: plan),
        Expanded(
          child: TeacherTimetableGrid(
            plan: plan,
            weekStart: weekStart,
            selectedBadge: effectiveBadge,
            singleDay: !isTablet && _singleDayPhone,
            compact: compactGrid,
            selectedEntry:
                isTablet && _tabletRightMode == _TabletRightMode.details
                ? _selectedEntry
                : null,
            onRefresh: _refreshAll,
            onSelectEntry: (dayCol, entry) {
              if (isTablet) {
                _handleTabletSelectEntry(dayCol, entry);
              } else {
                _openPhoneEntrySheet(
                  context,
                  plan: plan,
                  overview: overview,
                  dayColumnIndex: dayCol,
                  initialEntry: entry,
                  weekStart: weekStart,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  String? _formatPlanSubtitle(
    TeacherTimetableTarget? target,
    AppLocalizations l10n,
  ) {
    if (target == null) return null;
    if (target.isOwn) return target.label;
    final label = target.label.trim();
    if (label.isEmpty) return null;
    final prefix = switch (target.category) {
      TeacherTimetableCategory.teacher => l10n.teacherTimetableTypeTeacher,
      TeacherTimetableCategory.schoolClass => l10n.teacherTimetableTypeClass,
      TeacherTimetableCategory.room => l10n.teacherTimetableTypeRoom,
      TeacherTimetableCategory.breakSupervision =>
        l10n.teacherTimetableTypeBreakSupervision,
    };
    if (label.toLowerCase().startsWith(prefix.toLowerCase())) {
      return label;
    }
    return '$prefix $label';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offline == null) {
      ref.listen(connectionStatusProvider, (previous, next) {
        if (!mounted ||
            !TickerMode.valuesOf(context).enabled ||
            previous?.asData?.value != ConnectionStatus.disconnected ||
            next.asData?.value != ConnectionStatus.connected) {
          return;
        }
        final failure = _overviewSource.latestResponse.error?.exception;
        if (_overviewSource.latestResponse.status == FetcherStatus.error &&
            failure != null &&
            (failure is CacheUnavailableException ||
                CacheService.isTransportFailure(failure))) {
          unawaited(_overviewSource.fetchData(forceRefresh: true));
        }
        final target = _activeTarget;
        if (target != null &&
            (_planError != null ||
                !_loadedPlans.containsKey(
                  _planCacheKey(target, _selectedVersionDate),
                ))) {
          unawaited(_selectTarget(target, forceRefresh: true));
        }
      });
    }

    final l10n = AppLocalizations.of(context);
    final isNavRail = Responsive.isTablet(context);
    final isSplitView = Responsive.isSplitView(context);
    final isOffline = _watchIsOffline();

    return StreamBuilder<FetcherResponse<TeacherTimetableOverview>>(
      stream: _overviewSource.stream,
      initialData: _overviewSource.latestResponse,
      builder: (context, snapshot) {
        final response = snapshot.data;
        if (response?.status == FetcherStatus.error &&
            response?.content == null) {
          final error = response?.error?.exception;
          return Scaffold(
            appBar: AppBar(
              title: Text(timeTableDefinition.label(context)),
              leading: !isNavRail && widget.openDrawerCb != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => widget.openDrawerCb!(),
                    )
                  : null,
            ),
            body: error is CacheUnavailableException
                ? const OfflineDataUnavailableView()
                : AppletErrorView(
                    error: error is Exception
                        ? error
                        : UnknownException(error.toString()),
                    stack: response?.error?.stackTrace,
                    retry: () => _overviewSource.fetchData(forceRefresh: true),
                  ),
          );
        }

        final overview = response?.content;
        if (overview == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(timeTableDefinition.label(context)),
              leading: !isNavRail && widget.openDrawerCb != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => widget.openDrawerCb!(),
                    )
                  : null,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final ownTarget = _buildOwnTarget(
          overview,
          l10n.teacherTimetableOwnPlan,
        );
        _ensureInitialTargetLoaded(overview, l10n.teacherTimetableOwnPlan);

        final activePlan = _planForTarget(_activeTarget);
        final activeSubtitle = _formatPlanSubtitle(_activeTarget, l10n);
        final hasFreeRooms = overview.freeRoomsUrl != null && !isOffline;
        _scheduleOfflineAvailabilityCheck(
          isOffline: isOffline,
          overview: overview,
          ownTarget: ownTarget,
          activePlan: activePlan,
        );

        if (!isSplitView) {
          return _buildPhoneScaffold(
            context,
            overview: overview,
            ownTarget: ownTarget,
            activePlan: activePlan,
            activeSubtitle: activeSubtitle,
            hasFreeRooms: hasFreeRooms,
            isOffline: isOffline,
            showDrawerButton: !isNavRail && widget.openDrawerCb != null,
          );
        }

        return _buildTabletScaffold(
          context,
          overview: overview,
          ownTarget: ownTarget,
          activePlan: activePlan,
          activeSubtitle: activeSubtitle,
          hasFreeRooms: hasFreeRooms,
          isOffline: isOffline,
        );
      },
    );
  }

  /// Phone & mid-width candybar mode (width <= splitViewBreakpoint):
  /// Native Lanis AppBar + Grid + extended FAB opening the plan switcher modal.
  Widget _buildPhoneScaffold(
    BuildContext context, {
    required TeacherTimetableOverview overview,
    required TeacherTimetableTarget? ownTarget,
    required TeacherTimetablePlan? activePlan,
    required String? activeSubtitle,
    required bool hasFreeRooms,
    required bool isOffline,
    required bool showDrawerButton,
  }) {
    final l10n = AppLocalizations.of(context);
    final hasAnyPlanChoices =
        (ownTarget != null ? 1 : 0) +
            overview.teachers.length +
            overview.classes.length +
            overview.rooms.length +
            overview.breakSupervisions.length >
        1;

    return Scaffold(
      appBar: AppBar(
        leading: showDrawerButton
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              )
            : null,
        title: AppletAppBarTitle(
          title: Text(timeTableDefinition.label(context)),
          subtitle: activeSubtitle,
        ),
        actions: [
          if (activePlan != null && activePlan.hasMultipleVersions)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TimetableVersionButton(
                versions: activePlan.availableVersions,
                selectedDate: _selectedVersionDate ?? activePlan.planDate,
                defaultDate: _defaultVersionDate,
                compact: true,
                isVersionEnabled: isOffline
                    ? _isVersionAvailableOffline
                    : null,
                onSelected: _onSelectVersion,
              ),
            ),
          if (activePlan != null) _buildWeekBadgeAction(context, activePlan),
          if (hasFreeRooms)
            IconButton(
              tooltip: l10n.teacherTimetableFreeRooms,
              icon: const Icon(Icons.meeting_room_outlined),
              onPressed: () => _openPhoneFreeRoomsSheet(context),
            ),
          IconButton(
            tooltip: _singleDayPhone
                ? l10n.teacherTimetableWeekView
                : l10n.teacherTimetableDayView,
            icon: Icon(
              _singleDayPhone
                  ? Icons.calendar_today
                  : Icons.calendar_today_outlined,
            ),
            onPressed: () => setState(() => _singleDayPhone = !_singleDayPhone),
          ),
        ],
      ),
      body: _buildPlanBody(
        context: context,
        overview: overview,
        isTablet: false,
        compactGrid: true,
      ),
      floatingActionButton: hasAnyPlanChoices
          ? FloatingActionButton.extended(
              heroTag: 'teacher-timetable-plan-fab',
              icon: const Icon(Icons.swap_horiz),
              label: Text(l10n.teacherTimetablePlans),
              onPressed: () => _openPhonePlanSwitcher(
                context,
                overview,
                ownTarget,
                isOffline: isOffline,
              ),
            )
          : null,
    );
  }

  /// Tablet (Design 1B-2): 3-Pane View — Left collapsible catalog · Center plan ·
  /// Right on-demand details OR live Free Rooms search.
  Widget _buildTabletScaffold(
    BuildContext context, {
    required TeacherTimetableOverview overview,
    required TeacherTimetableTarget? ownTarget,
    required TeacherTimetablePlan? activePlan,
    required String? activeSubtitle,
    required bool hasFreeRooms,
    required bool isOffline,
  }) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final rightOpen =
        (hasFreeRooms && _tabletRightMode == _TabletRightMode.freeRooms) ||
        (_tabletRightMode == _TabletRightMode.details &&
            _selectedEntry != null &&
            activePlan != null);
    final fetchedAt = _fetchedAtForTarget(_activeTarget) ?? DateTime.now();
    final weekStart = timetableWeekStart(fetchedAt);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalW = constraints.maxWidth;
          // Keep the left catalog always visible when there is room for it;
          // only auto-collapse it on narrower tablets while the right pane is open.
          final showLeft = !(rightOpen && totalW < 840);
          final leftWidth = totalW >= 1040 ? 276.0 : 248.0;
          final rightWidth = totalW >= 960 ? 286.0 : 252.0;
          final centerWidth =
              totalW - (showLeft ? leftWidth : 0) - (rightOpen ? rightWidth : 0);
          final compactCenter = centerWidth < 460;

          final displayedRightMode = rightOpen
              ? _tabletRightMode
              : _lastRightMode;
          final displayedSelection = _selectedEntry ?? _lastSelectedEntry;
          final displayedPlan = _selectedEntry != null
              ? activePlan
              : _lastSelectedPlan;

          Widget rightContent;
          if (hasFreeRooms &&
              displayedRightMode == _TabletRightMode.freeRooms) {
            rightContent = KeyedSubtree(
              key: const ValueKey('right-free-rooms'),
              child: TeacherFreeRoomsPanel(
                weekday: _freeRoomsWeekday,
                selectedHours: _freeRoomsHours,
                availableHours: _freeRoomsAvailableHours,
                rooms: _freeRoomsList,
                loading: _freeRoomsLoading,
                error: _freeRoomsError,
                isTabletPane: true,
                onSelectWeekday: _onSelectFreeRoomWeekday,
                onToggleHour: _onToggleFreeRoomHour,
                onRetry: () => _loadFreeRooms(
                  useServerDefaults: !_freeRoomsInitialized,
                ),
                onOpenRoom: (target) => unawaited(
                  // Exact 1B-2 behavior: opening a free room loads it
                  // in the center grid while keeping Free Rooms open right.
                  _selectTarget(target, preserveFreeRoomsPane: true),
                ),
                onClose: () =>
                    setState(() => _tabletRightMode = _TabletRightMode.none),
              ),
            );
          } else if (displayedSelection != null && displayedPlan != null) {
            rightContent = KeyedSubtree(
              key: ValueKey(
                'right-detail:${displayedPlan.targetId}:${displayedSelection.entry.id}',
              ),
              child: TeacherEntryInspectorPanel(
                plan: displayedPlan,
                overview: overview,
                selection: displayedSelection,
                weekStart: weekStart,
                isTargetEnabled: isOffline ? _isTargetAvailableOffline : null,
                isOffline: isOffline,
                onSelectSibling: (sib) => setState(() {
                  final next = TeacherEntrySelection(
                    dayColumnIndex: displayedSelection.dayColumnIndex,
                    entry: sib,
                  );
                  _selectedEntry = next;
                  _lastSelectedEntry = next;
                }),
                onOpenTarget: (target) => unawaited(_selectTarget(target)),
                onClose: () => setState(() {
                  _tabletRightMode = _TabletRightMode.none;
                  _selectedEntry = null;
                }),
              ),
            );
          } else {
            rightContent = const SizedBox.shrink(key: ValueKey('right-empty'));
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AnimatedSidePane(
                open: showLeft,
                width: leftWidth,
                isRight: false,
                child: Material(
                  color: cs.surfaceContainerLow,
                  child: SafeArea(
                    left: false,
                    right: false,
                    bottom: false,
                    child: TeacherPlanCatalogPanel(
                      overview: overview,
                      ownTarget: ownTarget,
                      ownTeacherId: _ownTeacherId,
                      activeTarget: _activeTarget,
                      recentTargets: _resolveRecentTargets(overview),
                      expandedCategories: _expandedCategories,
                      isTargetEnabled: isOffline
                          ? _isTargetAvailableOffline
                          : null,
                      onToggleCategory: _toggleCatalogCategory,
                      onSelectTarget: (target) => unawaited(
                        _selectTarget(
                          target,
                          preserveFreeRoomsPane:
                              _tabletRightMode == _TabletRightMode.freeRooms,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeLeft: true,
                  removeRight: true,
                  child: Scaffold(
                    appBar: AppBar(
                      automaticallyImplyLeading: false,
                      leading: showLeft
                          ? null
                          : IconButton(
                              tooltip: l10n.teacherTimetableToggleCatalog,
                              icon: const Icon(Icons.view_sidebar_outlined),
                              onPressed: () => setState(() {
                                _tabletRightMode = _TabletRightMode.none;
                                _selectedEntry = null;
                              }),
                            ),
                      title: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.centerLeft,
                              children: [...previousChildren, ?currentChild],
                            ),
                        child: KeyedSubtree(
                          key: ValueKey('subtitle:$activeSubtitle'),
                          child: AppletAppBarTitle(
                            title: Text(timeTableDefinition.label(context)),
                            subtitle: activeSubtitle,
                          ),
                        ),
                      ),
                      actions: [
                        if (activePlan != null)
                          _buildWeekBadgeAction(context, activePlan),
                        if (activePlan != null &&
                            activePlan.hasMultipleVersions)
                          Padding(
                            padding: EdgeInsets.only(
                              right:
                                  hasFreeRooms &&
                                      _tabletRightMode !=
                                          _TabletRightMode.freeRooms
                                  ? 8
                                  : 12,
                            ),
                            child: TimetableVersionButton(
                              versions: activePlan.availableVersions,
                              selectedDate:
                                  _selectedVersionDate ?? activePlan.planDate,
                              defaultDate: _defaultVersionDate,
                              compact: compactCenter,
                              isVersionEnabled: isOffline
                                  ? _isVersionAvailableOffline
                                  : null,
                              onSelected: _onSelectVersion,
                            ),
                          ),
                        if (hasFreeRooms &&
                            _tabletRightMode != _TabletRightMode.freeRooms)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: FilterChip(
                              avatar: Icon(
                                Icons.meeting_room_outlined,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              label: Text(l10n.teacherTimetableFreeRooms),
                              selected: false,
                              showCheckmark: false,
                              onSelected: (_) => _toggleTabletFreeRooms(),
                            ),
                          ),
                      ],
                    ),
                    body: _buildPlanBody(
                      context: context,
                      overview: overview,
                      isTablet: true,
                      compactGrid: compactCenter,
                    ),
                  ),
                ),
              ),
              _AnimatedSidePane(
                open: rightOpen,
                width: rightWidth,
                isRight: true,
                child: Material(
                  color: cs.surfaceContainerLow,
                  child: SafeArea(
                    left: false,
                    right: false,
                    bottom: false,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: rightContent,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Smoothly animates a tablet sidebar sliding in/out without squeezing or
/// overflowing its child widgets during intermediate widths.
class _AnimatedSidePane extends StatelessWidget {
  final bool open;
  final double width;
  final bool isRight;
  final Widget child;

  const _AnimatedSidePane({
    required this.open,
    required this.width,
    required this.isRight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final fullWidth = width + 1;
    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: open ? fullWidth : 0,
        child: OverflowBox(
          alignment: isRight ? Alignment.centerLeft : Alignment.centerRight,
          minWidth: fullWidth,
          maxWidth: fullWidth,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            opacity: open ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !open,
              child: ExcludeSemantics(
                excluding: !open,
                child: FocusScope(
                  canRequestFocus: open,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isRight) const VerticalDivider(width: 1),
                      SizedBox(width: width, child: child),
                      if (!isRight) const VerticalDivider(width: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
