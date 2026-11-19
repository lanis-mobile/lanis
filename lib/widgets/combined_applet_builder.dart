import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/utils/applet_settings.dart';
import 'error_view.dart';
import '../features/offline/cached_data_source.dart';

typedef RefreshFunction = Future<void> Function();
typedef UpdateSetting = Future<void> Function(String key, dynamic value);
typedef BuilderFunction<T> =
    Widget Function(
      BuildContext,
      T,
      AccountType,
      Map<String, dynamic>,
      UpdateSetting,
      RefreshFunction? refresh,
    );

class CombinedAppletBuilder<T> extends ConsumerStatefulWidget {
  final AppletDataSource<T> parser;
  final TypedSettings? settings;
  final String phpUrl;
  final Map<String, dynamic> settingsDefaults;
  final AccountType accountType;
  final BuilderFunction<T> builder;
  final bool showErrorAppBar;
  final AppBar? loadingAppBar;

  const CombinedAppletBuilder({
    super.key,
    required this.parser,
    this.settings,
    required this.phpUrl,
    required this.settingsDefaults,
    required this.accountType,
    required this.builder,
    this.showErrorAppBar = false,
    this.loadingAppBar,
  });

  @override
  ConsumerState<CombinedAppletBuilder<T>> createState() =>
      _CombinedAppletBuilderState<T>();
}

class _CombinedAppletBuilderState<T>
    extends ConsumerState<CombinedAppletBuilder<T>>
    with WidgetsBindingObserver {
  late Map<String, dynamic> appletSettings;
  bool _loading = true;
  bool _fetchStarted = false;
  bool _needsRecovery = false;
  bool _wasVisible = false;

  Widget _loadingState() {
    return Scaffold(
      appBar: widget.loadingAppBar,
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  String _settingKey(String key) => '${widget.phpUrl}/$key';

  void initSettings() {
    final settings =
        widget.settings ?? ref.read(accountSpecificSettingsProvider);
    final loaded = <String, dynamic>{};
    for (final entry in widget.settingsDefaults.entries) {
      if (settings == null) {
        loaded[entry.key] = entry.value;
        continue;
      }
      loaded[entry.key] = resolveStoredAppletSetting(
        settings,
        _settingKey(entry.key),
        entry.value,
      );
    }
    appletSettings = loaded;
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final settings =
        widget.settings ?? ref.read(accountSpecificSettingsProvider);
    if (settings == null) return;
    final namespaced = _settingKey(key);
    persistAppletSetting(settings, namespaced, value);
    setState(() {
      if (value is Map) {
        appletSettings[key] = Map<String, dynamic>.from(value);
      } else {
        appletSettings[key] = value;
      }
    });
  }

  void _syncVisibility() {
    // IndexedStack disables [TickerMode] for offstage branches.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active =
        TickerMode.valuesOf(context).enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    final becameVisible = active && !_wasVisible;
    _wasVisible = active;
    if (active) {
      if (becameVisible && _fetchStarted) initSettings();
      widget.parser.startAutoRefresh();
      if (!_fetchStarted) {
        _fetchStarted = true;
        widget.parser.fetchData();
      }
    } else {
      widget.parser.stopAutoRefresh();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncVisibility();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(covariant CombinedAppletBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parser != widget.parser ||
        oldWidget.phpUrl != widget.phpUrl) {
      oldWidget.parser.stopAutoRefresh();
      setState(() {
        _loading = true;
        _fetchStarted = false;
      });
      initSettings();
      _syncVisibility();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final fetched = _fetchStarted;
      _syncVisibility();
      if (fetched && TickerMode.valuesOf(context).enabled) {
        widget.parser.fetchData(forceRefresh: true);
      }
    } else {
      widget.parser.stopAutoRefresh();
    }
  }

  @override
  void dispose() {
    widget.parser.stopAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localOnly =
        widget.parser is CachedDataSource<T> &&
        (widget.parser as CachedDataSource<T>).cacheOnly;
    if (!localOnly) {
      ref.listen(connectionStatusProvider, (previous, next) {
        if (!mounted || !TickerMode.valuesOf(context).enabled) return;
        final latest = widget.parser.latestResponse;
        final failure = latest?.error?.exception;
        if (next.asData?.value == ConnectionStatus.disconnected &&
            previous?.asData?.value == ConnectionStatus.connected) {
          _needsRecovery = true;
        }
        final canRecover =
            (_needsRecovery && latest?.content != null) ||
            latest?.contentStatus == ContentStatus.offline ||
            (latest?.status == FetcherStatus.error &&
                failure != null &&
                (failure is CacheUnavailableException ||
                    CacheService.isTransportFailure(failure)));
        if (previous?.asData?.value == ConnectionStatus.disconnected &&
            next.asData?.value == ConnectionStatus.connected &&
            canRecover) {
          _needsRecovery = false;
          widget.parser.fetchData(forceRefresh: true);
        }
      });
    }
    return StreamBuilder(
      stream: widget.parser.stream,
      initialData: widget.parser.latestResponse,
      builder: (context, snapshot) {
        if (snapshot.hasError || snapshot.data?.status == FetcherStatus.error) {
          if ((snapshot.error ?? snapshot.data?.error?.exception)
              is CacheUnavailableException) {
            return Scaffold(
              appBar: widget.loadingAppBar,
              body: const OfflineDataUnavailableView(),
            );
          }
          return Scaffold(
            appBar: widget.loadingAppBar,
            body: AppletErrorView(
              showAppBar:
                  widget.showErrorAppBar && widget.loadingAppBar == null,
              error: snapshot.hasError
                  ? UnknownException(snapshot.error.toString())
                  : snapshot.data!.error != null
                  ? (snapshot.data!.error!.exception is Exception
                        ? snapshot.data!.error!.exception as Exception
                        : UnknownException(
                            snapshot.data!.error!.exception.toString(),
                          ))
                  : snapshot.data!.contentStatus == ContentStatus.offline
                  ? NoConnectionException()
                  : UnknownException(),
              stack: snapshot.data?.error?.stackTrace,
              retry: () => widget.parser.fetchData(forceRefresh: true),
            ),
          );
        } else if (!snapshot.hasData ||
            (snapshot.data?.status == FetcherStatus.fetching &&
                snapshot.data?.content == null) ||
            _loading) {
          return _loadingState();
        } else {
          return widget.builder(
            context,
            snapshot.data!.content as T,
            widget.accountType,
            appletSettings,
            _updateSetting,
            () async => widget.parser.fetchData(forceRefresh: true),
          );
        }
      },
    );
  }
}
