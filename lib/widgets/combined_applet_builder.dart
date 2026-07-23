import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/generated/l10n.dart';
import 'error_view.dart';

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
  final AppletParser<T> parser;
  final String phpUrl;
  final Map<String, dynamic> settingsDefaults;
  final AccountType accountType;
  final BuilderFunction<T> builder;
  final bool showErrorAppBar;
  final AppBar? loadingAppBar;

  const CombinedAppletBuilder({
    super.key,
    required this.parser,
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
    extends ConsumerState<CombinedAppletBuilder<T>> {
  late Map<String, dynamic> appletSettings;
  bool _loading = true;
  bool _fetchStarted = false;

  Widget _loadingState() {
    return Scaffold(
      appBar: widget.loadingAppBar,
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  String _settingKey(String key) => '${widget.phpUrl}/$key';

  void initSettings() {
    final settings = ref.read(accountSpecificSettingsProvider);
    final loaded = <String, dynamic>{};
    for (final entry in widget.settingsDefaults.entries) {
      if (settings == null) {
        loaded[entry.key] = entry.value;
        continue;
      }
      final storedMap = settings.getJsonMap(_settingKey(entry.key));
      final storedList = settings.getJsonList(_settingKey(entry.key));
      // Prefer typed reads for primitives in defaults
      final boolVal = settings.getBool(_settingKey(entry.key));
      final intVal = settings.getInt(_settingKey(entry.key));
      final strVal = settings.getString(_settingKey(entry.key));
      if (storedMap != null) {
        loaded[entry.key] = storedMap;
      } else if (storedList != null) {
        loaded[entry.key] = storedList;
      } else if (boolVal != null) {
        loaded[entry.key] = boolVal;
      } else if (intVal != null) {
        loaded[entry.key] = intVal;
      } else if (strVal != null) {
        loaded[entry.key] = strVal;
      } else {
        loaded[entry.key] = entry.value;
      }
    }
    appletSettings = loaded;
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final settings = ref.read(accountSpecificSettingsProvider);
    if (settings == null) return;
    final namespaced = _settingKey(key);
    if (value is bool) {
      settings.setBool(namespaced, value);
    } else if (value is int) {
      settings.setInt(namespaced, value);
    } else if (value is String) {
      settings.setString(namespaced, value);
    } else if (value is Map<String, dynamic>) {
      settings.setJsonMap(namespaced, value);
    } else if (value is List) {
      settings.setJsonList(namespaced, value);
    } else if (value == null) {
      settings.remove(namespaced);
    } else {
      settings.setString(namespaced, value.toString());
    }
    setState(() => appletSettings[key] = value);
  }

  void _syncVisibility() {
    // IndexedStack disables [TickerMode] for offstage branches.
    final active = TickerMode.of(context);
    if (active) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      initSettings();
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
  void dispose() {
    widget.parser.stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.parser.stream,
      initialData: widget.parser.latestResponse,
      builder: (context, snapshot) {
        if (snapshot.hasError || snapshot.data?.status == FetcherStatus.error) {
          return Scaffold(
            body: AppletErrorView(
              showAppBar: widget.showErrorAppBar,
              error: snapshot.data!.contentStatus == ContentStatus.offline
                  ? NoConnectionException()
                  : snapshot.data!.error != null
                  ? (snapshot.data!.error!.exception is Exception
                        ? snapshot.data!.error!.exception as Exception
                        : UnknownException(
                            snapshot.data!.error!.exception.toString(),
                          ))
                  : UnknownException(),
              stack: snapshot.data!.error?.stackTrace,
              retry: snapshot.data!.contentStatus == ContentStatus.online
                  ? () => widget.parser.fetchData(forceRefresh: true)
                  : null,
            ),
          );
        } else if (!snapshot.hasData ||
            snapshot.data?.status == FetcherStatus.fetching ||
            _loading) {
          return _loadingState();
        } else {
          return Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (snapshot.data?.contentStatus == ContentStatus.offline)
                Container(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: SafeArea(
                    left: false,
                    right: false,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.offline_pin,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${AppLocalizations.of(context).offline} (${snapshot.data?.fetchedAt.format('E dd.MM HH:mm')})',
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop:
                      snapshot.data?.contentStatus == ContentStatus.offline,
                  child: widget.builder(
                    context,
                    snapshot.data!.content as T,
                    widget.accountType,
                    appletSettings,
                    _updateSetting,
                    () async {
                      await widget.parser.fetchData(forceRefresh: true);
                    },
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }
}
