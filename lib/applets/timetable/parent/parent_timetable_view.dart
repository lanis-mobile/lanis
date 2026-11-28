import 'package:lanis/widgets/applet_app_bar_title.dart';
import '../timetable_settings_scope.dart';
import '../timetable_settings_view.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/offline/cache_context.dart';
import 'package:lanis/features/offline/cached_data_source.dart';
import 'package:lanis/features/offline/foreground_connection_monitor.dart';
import 'package:lanis/features/offline/session_reauth.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/widgets/error_view.dart';
import '../student/student_timetable_better_view.dart';

AppBar _timetableAppBar(
  BuildContext context, {
  Function? openDrawerCb,
  PreferredSizeWidget? bottom,
  bool customize = false,
  String? pupilName,
}) => AppBar(
  title: customize
      ? null
      : AppletAppBarTitle(
          title: Text(AppLocalizations.of(context).timeTable),
          subtitle: pupilName,
        ),
  toolbarHeight: customize ? 0 : kToolbarHeight,
  primary: !customize,
  automaticallyImplyLeading: !customize,
  backgroundColor: customize ? Theme.of(context).scaffoldBackgroundColor : null,
  bottom: bottom,
  leading: openDrawerCb == null
      ? null
      : IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => openDrawerCb(),
        ),
);

class ParentTimetableView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  final OfflineCacheContext? offline;
  final bool customize;
  final ValueChanged<String?>? onSinglePupilChanged;
  const ParentTimetableView({
    super.key,
    this.openDrawerCb,
    this.offline,
    this.customize = false,
    this.onSinglePupilChanged,
  });
  @override
  ConsumerState<ParentTimetableView> createState() =>
      _ParentTimetableViewState();
}

class _ParentTimetableViewState extends ConsumerState<ParentTimetableView>
    with WidgetsBindingObserver {
  late final CachedDataSource<ParentTimetableHome> _home;
  String? _reportedSinglePupil;
  void _reportSinglePupil(String? name) {
    if (name == _reportedSinglePupil) return;
    _reportedSinglePupil = name;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSinglePupilChanged?.call(name);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _home = CachedDataSource(
      read: _readHome,
      readCache: _readCachedHome,
      cacheOnly: widget.offline != null,
      refreshInterval: Applets.timetable.refreshInterval,
    );
    unawaited(_home.fetchData());
  }

  CacheService get _cache {
    final offline = widget.offline;
    return offline != null ? offline.cache : ref.read(cacheServiceProvider);
  }

  Future<MaybeCacheResult<ParentTimetableHome>> _readCachedHome() =>
      _cache.readCacheFor(
        accountId:
            widget.offline?.account.localId ??
            ref.read(activeAccountProvider)!.localId,
        request: TimetableParentParserCacheRequests.getHome(),
      );

  Future<MaybeCacheResult<ParentTimetableHome>> _readHome() {
    final offline = widget.offline;
    if (offline != null) {
      return offline.read(TimetableParentParserCacheRequests.getHome());
    }
    final isOfflineNet = ref.read(networkInterfaceAvailableProvider) == false;
    final policy = isOfflineNet
        ? CacheReadPolicy.cacheOnly
        : CacheReadPolicy.networkFirst;
    final session = isOfflineNet ? null : ref.read(sessionProvider).asData?.value;
    return runWithSessionReauth(
      session,
      () => ref
          .read(timetableParentParserProvider)
          .cached
          .getHome(cachePolicy: policy),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.valuesOf(context).enabled) {
      _home.startAutoRefresh();
    } else {
      _home.stopAutoRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        TickerMode.valuesOf(context).enabled) {
      _home.startAutoRefresh();
      unawaited(_home.fetchData(forceRefresh: true));
    } else {
      _home.stopAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _home.dispose();
    super.dispose();
  }

  int get _accountId =>
      widget.offline?.account.localId ??
      ref.read(activeAccountProvider)!.localId;

  Future<Set<String>> _availableCachedPupilIds(
    List<ParentTimetableReference> references,
  ) async {
    final requestToPupilId =
        <CacheRequest<ParentTimetableLoaded>, String>{
      for (final reference in references)
        TimetableParentParserCacheRequests.getTimetable(reference):
            reference.pupilId,
    };
    if (requestToPupilId.isEmpty) return const {};
    final available = await _cache.availableRequestsFor(
      accountId: _accountId,
      requests: requestToPupilId.keys,
    );
    return {for (final req in available) requestToPupilId[req]!};
  }

  Future<Set<String>> _availableCachedPupilVersionDates(
    String pupilId,
    List<String> dates,
  ) async {
    final trimmedPupil = pupilId.trim();
    final requestToDate = <CacheRequest<ParentTimetableLoaded>, String>{
      for (final d in dates)
        if (d.trim().isNotEmpty)
          TimetableParentParserCacheRequests.getTimetableForPupil(
            trimmedPupil,
            d.trim(),
          ): d.trim(),
    };
    if (requestToDate.isEmpty) return const {};
    final available = await _cache.availableRequestsFor(
      accountId: _accountId,
      requests: requestToDate.keys,
    );
    return {for (final req in available) requestToDate[req]!};
  }

  Future<Set<String>> _availableCachedReferenceVersionDates(
    ParentTimetableReference reference,
    List<String> dates,
  ) async {
    final requestToDate = <CacheRequest<ParentTimetableLoaded>, String>{
      for (final d in dates)
        if (d.trim().isNotEmpty)
          TimetableParentParserCacheRequests.getTimetable(
            reference.withDate(d.trim()),
          ): d.trim(),
    };
    if (requestToDate.isEmpty) return const {};
    final available = await _cache.availableRequestsFor(
      accountId: _accountId,
      requests: requestToDate.keys,
    );
    return {for (final req in available) requestToDate[req]!};
  }

  Future<MaybeCacheResult<ParentTimetableLoaded>> _readCachedPlan(
    ParentTimetableReference reference,
  ) => _cache.readCacheFor(
    accountId: _accountId,
    request: TimetableParentParserCacheRequests.getTimetable(reference),
  );

  Future<MaybeCacheResult<ParentTimetableLoaded>> _readPlan(
    ParentTimetableReference reference,
  ) {
    final offline = widget.offline;
    if (offline != null) return _readCachedPlan(reference);
    final isOfflineNet = ref.read(networkInterfaceAvailableProvider) == false;
    final policy = isOfflineNet
        ? CacheReadPolicy.cacheOnly
        : CacheReadPolicy.networkFirst;
    final session = isOfflineNet ? null : ref.read(sessionProvider).asData?.value;
    return runWithSessionReauth(
      session,
      () => ref
          .read(timetableParentParserProvider)
          .cached
          .getTimetable(reference, cachePolicy: policy),
    );
  }

  Future<MaybeCacheResult<ParentTimetableLoaded>> _readPupilVersion(
    String pupilId,
    String date,
  ) {
    final offline = widget.offline;
    if (offline != null) {
      return _cache.readCacheFor(
        accountId: offline.account.localId,
        request: TimetableParentParserCacheRequests.getTimetableForPupil(
          pupilId.trim(),
          date.trim(),
        ),
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
          .read(timetableParentParserProvider)
          .loadCachedTimetableForPupil(pupilId, date, policy: policy),
    );
  }

  TypedSettings? get _settings =>
      widget.offline?.settings ?? ref.read(accountSpecificSettingsProvider);

  @override
  Widget build(BuildContext context) {
    if (widget.offline == null) {
      ref.listen(connectionStatusProvider, (previous, next) {
        final failure = _home.latestResponse.error?.exception;
        if (mounted &&
            TickerMode.valuesOf(context).enabled &&
            previous?.asData?.value == ConnectionStatus.disconnected &&
            next.asData?.value == ConnectionStatus.connected &&
            _home.latestResponse.status == FetcherStatus.error &&
            failure != null &&
            (failure is CacheUnavailableException ||
                CacheService.isTransportFailure(failure))) {
          unawaited(_home.fetchData(forceRefresh: true));
        }
      });
    }
    return StreamBuilder<FetcherResponse<ParentTimetableHome>>(
      stream: _home.stream,
      initialData: _home.latestResponse,
      builder: (context, snapshot) {
        final response = snapshot.data;
        if (response?.status == FetcherStatus.error) {
          final error = response?.error?.exception;
          return Scaffold(
            appBar: _timetableAppBar(
              context,
              openDrawerCb: widget.openDrawerCb,
              customize: widget.customize,
            ),
            body: error is CacheUnavailableException
                ? const OfflineDataUnavailableView()
                : AppletErrorView(
                    error: error is Exception
                        ? error
                        : UnknownException(error.toString()),
                    stack: response?.error?.stackTrace,
                    retry: () => _home.fetchData(forceRefresh: true),
                  ),
          );
        }
        final home = response?.content;
        if (home == null) {
          return Scaffold(
            appBar: _timetableAppBar(
              context,
              openDrawerCb: widget.openDrawerCb,
              customize: widget.customize,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        switch (home) {
          case ParentTimetableLoaded loaded:
            _reportSinglePupil(loaded.pupilName);
            MaybeCacheResult<TimeTable> map(
              MaybeCacheResult<ParentTimetableHome> value,
            ) => value.map((home) {
              if (home is! ParentTimetableLoaded) {
                throw UnknownException('Timetable selection changed');
              }
              return home.timetable;
            });
            return _PlanScreen(
              key: ValueKey(loaded.pupilId),
              pupilName: loaded.pupilName,
              settings: timetableSettingsForPupil(_settings, loaded.pupilId),
              customize: widget.customize,
              openDrawerCb: widget.openDrawerCb,
              cacheOnly: widget.offline != null,
              initial: MaybeCacheResult(
                data: loaded.timetable,
                cacheStatus: response!.contentStatus == ContentStatus.offline
                    ? CacheStatus.cache
                    : CacheStatus.network,
                fetchedAt: response.fetchedAt,
                responseAt: response.responseAt ?? response.fetchedAt,
                expiresAt: response.expiresAt!,
              ),
              readCache: () async => map(await _readCachedHome()),
              read: () async => map(await _readHome()),
              loadVersion: (date) async => (await _readPupilVersion(
                loaded.pupilId,
                date,
              )).map((value) => value.timetable),
              availableCachedVersionDates: (dates) =>
                  _availableCachedPupilVersionDates(loaded.pupilId, dates),
            );
          case ParentTimetableSelection selection:
            _reportSinglePupil(
              selection.timetables.length == 1
                  ? selection.timetables.single.pupilName
                  : null,
            );
            return _TimetableTabs(
              selection: selection,
              customize: widget.customize,
              settings: _settings,
              openDrawerCb: widget.openDrawerCb,
              cacheOnly: widget.offline != null,
              read: _readPlan,
              readCache: _readCachedPlan,
              availableCachedPupilIds: _availableCachedPupilIds,
              availableCachedVersionDates:
                  _availableCachedReferenceVersionDates,
            );
        }
      },
    );
  }
}

class _TimetableTabs extends StatefulWidget {
  final ParentTimetableSelection selection;
  final TypedSettings? settings;
  final Function? openDrawerCb;
  final bool cacheOnly;
  final bool customize;
  final Future<MaybeCacheResult<ParentTimetableLoaded>> Function(
    ParentTimetableReference,
  )
  read;
  final Future<MaybeCacheResult<ParentTimetableLoaded>> Function(
    ParentTimetableReference,
  )
  readCache;
  final Future<Set<String>> Function(List<ParentTimetableReference>)
  availableCachedPupilIds;
  final Future<Set<String>> Function(
    ParentTimetableReference,
    List<String>,
  )
  availableCachedVersionDates;
  const _TimetableTabs({
    required this.selection,
    required this.settings,
    required this.openDrawerCb,
    required this.cacheOnly,
    this.customize = false,
    required this.read,
    required this.readCache,
    required this.availableCachedPupilIds,
    required this.availableCachedVersionDates,
  });
  @override
  State<_TimetableTabs> createState() => _TimetableTabsState();
}

class _TimetableTabsState extends State<_TimetableTabs>
    with TickerProviderStateMixin {
  late TabController _tabs;
  final _visited = <String>{};
  final _appBar = ValueNotifier<AppBar?>(null);
  final _headers = <String, AppBar>{};
  int _selectedIndex = 0;
  int _cacheRevision = 0;
  bool _cacheReady = false;
  final _cachedPlans = <String, MaybeCacheResult<TimeTable>>{};
  List<ParentTimetableReference> get _references => widget.selection.timetables;

  @override
  void initState() {
    super.initState();
    _createTabs();
    _prepareCachedPlans();
  }

  void _prepareCachedPlans() {
    final revision = ++_cacheRevision;
    _cacheReady = !widget.cacheOnly;
    _cachedPlans.clear();
    if (!widget.cacheOnly) return;
    // Batch-check cached pupils first in one metadata query, then load only
    // the available cached entries. Additional online requests remain lazy.
    unawaited(
      () async {
        Set<String> availableIds;
        try {
          availableIds = await widget.availableCachedPupilIds(_references);
        } catch (_) {
          availableIds = const {};
        }
        if (!mounted || revision != _cacheRevision) return;
        final entries = await Future.wait([
          for (final reference in _references)
            if (availableIds.contains(reference.pupilId))
              widget
                  .readCache(reference)
                  .then<MapEntry<String, MaybeCacheResult<TimeTable>>?>(
                    (result) => MapEntry(
                      reference.pupilId,
                      result.map((value) => value.timetable),
                    ),
                    onError: (Object _, StackTrace _) => null,
                  ),
        ]);
        if (!mounted || revision != _cacheRevision) return;
        setState(() {
          _cachedPlans.addEntries(
            entries.whereType<MapEntry<String, MaybeCacheResult<TimeTable>>>(),
          );
          _visited.addAll(_cachedPlans.keys);
          _cacheReady = true;
        });
      }(),
    );
  }

  void _createTabs([String? selected]) {
    final index = _references.indexWhere(
      (reference) => reference.pupilId == selected,
    );
    _tabs = TabController(
      length: _references.length,
      initialIndex: index < 0 ? 0 : index,
      vsync: this,
    );
    _selectedIndex = _tabs.index;
    if (_references.isNotEmpty) _visited.add(_references[_tabs.index].pupilId);
    _tabs.addListener(_onSelected);
  }

  void _onSelected() {
    if (_references.isEmpty || _selectedIndex == _tabs.index) return;
    _selectedIndex = _tabs.index;
    final id = _references[_tabs.index].pupilId;
    _appBar.value = _headers[id];
    setState(() => _visited.add(id));
  }

  @override
  void didUpdateWidget(covariant _TimetableTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.selection.timetables
        .map((reference) => reference.pupilId)
        .toList();
    final ids = _references.map((reference) => reference.pupilId).toList();
    if (!listEquals(oldIds, ids)) {
      final selected = oldIds.isEmpty ? null : oldIds[_tabs.index];
      _tabs.dispose();
      _headers.clear();
      _appBar.value = null;
      _visited.retainAll(ids);
      _createTabs(selected);
      _prepareCachedPlans();
    } else if (oldWidget.cacheOnly != widget.cacheOnly) {
      _prepareCachedPlans();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _appBar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_references.isEmpty) {
      return Scaffold(
        appBar: _timetableAppBar(
          context,
          openDrawerCb: widget.openDrawerCb,
          customize: widget.customize,
        ),
        body: Center(child: Text(AppLocalizations.of(context).noEntries)),
      );
    }
    if (!_cacheReady) {
      return Scaffold(
        appBar: _timetableAppBar(
          context,
          openDrawerCb: widget.openDrawerCb,
          customize: widget.customize,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final tabs = _references.length <= 1
        ? null
        : TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final reference in _references)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(reference.pupilName),
                      if (widget.cacheOnly &&
                          !_cachedPlans.containsKey(reference.pupilId)) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.error_outline, size: 16),
                      ],
                    ],
                  ),
                ),
            ],
          );
    return ValueListenableBuilder<AppBar?>(
      valueListenable: _appBar,
      builder: (context, appBar, child) => Scaffold(
        appBar:
            appBar ??
            _timetableAppBar(
              context,
              pupilName: _references.length == 1
                  ? _references.single.pupilName
                  : null,
              bottom: tabs,
              openDrawerCb: widget.openDrawerCb,
              customize: widget.customize,
            ),
        body: child,
      ),
      child: TabBarView(
        controller: _tabs,
        children: [
          for (final (index, reference) in _references.indexed)
            TickerMode(
              key: ValueKey(reference.pupilId),
              enabled: index == _selectedIndex,
              child:
                  widget.cacheOnly &&
                      !_cachedPlans.containsKey(reference.pupilId)
                  ? const OfflineDataUnavailableView()
                  : _visited.contains(reference.pupilId)
                  ? _PlanScreen(
                      key: ValueKey(reference.pupilId),
                      pupilName: _references.length == 1
                          ? reference.pupilName
                          : null,
                      initial: _cachedPlans[reference.pupilId],
                      settings: timetableSettingsForPupil(
                        widget.settings,
                        reference.pupilId,
                      ),
                      customize: widget.customize,
                      openDrawerCb: widget.openDrawerCb,
                      cacheOnly: widget.cacheOnly,
                      appBarBottom: tabs,
                      showAppBar: false,
                      onAppBarChanged: (appBar) {
                        if (!mounted) return;
                        _headers[reference.pupilId] = appBar;
                        if (_references[_tabs.index].pupilId ==
                            reference.pupilId) {
                          _appBar.value = appBar;
                        }
                      },
                      readCache: () async => (await widget.readCache(
                        reference,
                      )).map((value) => value.timetable),
                      read: () async => (await widget.read(
                        reference,
                      )).map((value) => value.timetable),
                      loadVersion: (date) async => (await widget.read(
                        reference.withDate(date),
                      )).map((value) => value.timetable),
                      availableCachedVersionDates: (dates) =>
                          widget.availableCachedVersionDates(reference, dates),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _PlanScreen extends StatefulWidget {
  final Future<MaybeCacheResult<TimeTable>> Function() read;
  final MaybeCacheResult<TimeTable>? initial;
  final Future<MaybeCacheResult<TimeTable>> Function()? readCache;
  final Future<MaybeCacheResult<TimeTable>> Function(String date)? loadVersion;
  final Future<Set<String>> Function(List<String> dates)?
  availableCachedVersionDates;
  final TypedSettings? settings;
  final bool cacheOnly;
  final bool customize;
  final PreferredSizeWidget? appBarBottom;
  final bool showAppBar;
  final String? pupilName;
  final ValueChanged<AppBar>? onAppBarChanged;
  final Function? openDrawerCb;
  const _PlanScreen({
    super.key,
    required this.read,
    this.initial,
    this.readCache,
    this.loadVersion,
    this.availableCachedVersionDates,
    this.settings,
    this.cacheOnly = false,
    this.customize = false,
    this.appBarBottom,
    this.showAppBar = true,
    this.pupilName,
    this.onAppBarChanged,
    this.openDrawerCb,
  });
  @override
  State<_PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<_PlanScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final CachedDataSource<TimeTable> source;
  @override
  void initState() {
    super.initState();
    source = CachedDataSource(
      read: () => widget.read(),
      initial: widget.initial,
      readCache: widget.readCache,
      cacheOnly: widget.cacheOnly,
      refreshInterval: Applets.timetable.refreshInterval,
    );
  }

  @override
  void didUpdateWidget(covariant _PlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initial = widget.initial;
    if (initial != null &&
        (initial.fetchedAt != oldWidget.initial?.fetchedAt ||
            initial.responseAt != oldWidget.initial?.responseAt) &&
        DateTime.now().isBefore(initial.expiresAt)) {
      source.updateResult(initial);
    }
  }

  @override
  void dispose() {
    source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.customize) {
      return TimetableSettingsView(
        accountType: AccountType.parent,
        dataSource: source,
        settings: widget.settings,
        appBarBottom: widget.appBarBottom,
        showAppBar: widget.showAppBar,
        onAppBarChanged: widget.onAppBarChanged,
      );
    }
    return StudentTimetableBetterView(
      dataSource: source,
      settings: widget.settings,
      accountType: AccountType.parent,
      pupilName: widget.pupilName,
      openDrawerCb: widget.openDrawerCb,
      appBarBottom: widget.appBarBottom,
      showAppBar: widget.showAppBar,
      onAppBarChanged: widget.onAppBarChanged,
      loadVersion: widget.loadVersion,
      availableCachedVersionDates: widget.availableCachedVersionDates,
    );
  }
}
