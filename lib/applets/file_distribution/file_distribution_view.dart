import 'dart:async';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/file_distribution/definition.dart';
import 'package:lanis/features/offline/cache_context.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/file_operations.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/utils/url_modal.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:lanis/widgets/file_chip.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

enum _DistributionFilter { all, unread, files }

class FileDistributionView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  final AppletDataSource<FileDistributionHome>? dataSource;
  final TypedSettings? settings;
  final AccountType? accountType;

  const FileDistributionView({
    super.key,
    this.openDrawerCb,
    this.dataSource,
    this.settings,
    this.accountType,
  });

  @override
  ConsumerState<FileDistributionView> createState() =>
      _FileDistributionViewState();
}

class _FileDistributionViewState extends ConsumerState<FileDistributionView> {
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  static const Duration _autoReadDelay = Duration(seconds: 8);

  _DistributionFilter _filter = _DistributionFilter.all;
  int? _selectedId;
  final Set<int> _expandedIds = {};
  final Set<int> _locallyReadIds = {};
  final Set<int> _markingReadIds = {};
  final ValueNotifier<int> _scrollTick = ValueNotifier<int>(0);

  @override
  void dispose() {
    _scrollTick.dispose();
    super.dispose();
  }

  bool _isUnread(FileDistributionItem item) =>
      item.isUnread && !_locallyReadIds.contains(item.id);

  List<FileDistributionItem> _filteredItems(List<FileDistributionItem> items) {
    return switch (_filter) {
      _DistributionFilter.all => items,
      _DistributionFilter.unread => items.where(_isUnread).toList(),
      _DistributionFilter.files =>
        items.where((item) => item.files.isNotEmpty).toList(),
    };
  }

  String? _formatDateRange(FileDistributionItem item) {
    final from = item.validFrom;
    final until = item.validUntil;
    if (from == null && until == null) return null;
    if (from != null && until != null) {
      return '${_dateFormat.format(from)} – ${_dateFormat.format(until)}';
    }
    return _dateFormat.format((from ?? until)!);
  }

  Future<void> _markAsRead(
    FileDistributionItem item,
    AppletDataSource<FileDistributionHome> parser, {
    required bool isOffline,
  }) async {
    if (isOffline || !item.canMarkAsRead || !_isUnread(item)) return;
    if (parser is! FileDistributionParser) return;
    if (_markingReadIds.contains(item.id)) return;

    setState(() {
      _markingReadIds.add(item.id);
      _locallyReadIds.add(item.id);
    });
    try {
      final ok = await parser.markAsRead(item.id);
      if (!mounted) return;
      if (ok) {
        await parser.fetchData(forceRefresh: true);
      } else {
        setState(() => _locallyReadIds.remove(item.id));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _locallyReadIds.remove(item.id));
      }
    } finally {
      if (mounted) {
        setState(() => _markingReadIds.remove(item.id));
      }
    }
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(AppLocalizations.of(context).fileDistribution),
      leading: widget.openDrawerCb != null
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => widget.openDrawerCb!(),
            )
          : null,
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    List<FileDistributionItem> allItems, {
    EdgeInsets padding = const EdgeInsets.only(bottom: 10),
  }) {
    final l10n = AppLocalizations.of(context);
    final unreadCount = allItems.where(_isUnread).length;
    final filesCount = allItems.where((i) => i.files.isNotEmpty).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        spacing: 8,
        children: [
          FilterChip(
            label: Text(l10n.fileDistributionFilterAll(allItems.length)),
            selected: _filter == _DistributionFilter.all,
            onSelected: (_) =>
                setState(() => _filter = _DistributionFilter.all),
          ),
          FilterChip(
            label: Text(l10n.fileDistributionFilterUnread(unreadCount)),
            selected: _filter == _DistributionFilter.unread,
            onSelected: (_) =>
                setState(() => _filter = _DistributionFilter.unread),
          ),
          FilterChip(
            label: Text(l10n.fileDistributionFilterFiles(filesCount)),
            selected: _filter == _DistributionFilter.files,
            onSelected: (_) =>
                setState(() => _filter = _DistributionFilter.files),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool scrollable = true}) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.move_to_inbox_outlined,
                size: 28,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.fileDistribution,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.fileDistributionEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    if (!scrollable) return content;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: content,
        ),
      ),
    );
  }

  Widget _buildNewBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppLocalizations.of(context).fileDistributionNewBadge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, FileDistributionItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateRange = _formatDateRange(item);
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (dateRange != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(dateRange, style: style),
            ],
          ),
        if (item.creatorName != null && item.creatorName!.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(item.creatorName!, style: style),
            ],
          ),
      ],
    );
  }

  static bool _isImageFile(FileDistributionFile file) =>
      const {'png', 'jpg', 'jpeg'}.contains(file.fileExtension.toLowerCase());

  List<FileDistributionFile> _imageAttachments(FileDistributionItem item) =>
      item.files.where(_isImageFile).toList();

  List<FileDistributionFile> _nonImageAttachments(FileDistributionItem item) =>
      item.files.where((f) => !_isImageFile(f)).toList();

  Widget _buildPhoneCard(
    BuildContext context,
    FileDistributionItem item,
    AppletDataSource<FileDistributionHome> parser,
    bool isOffline,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final unread = _isUnread(item);
    final canAutoRead = unread && item.canMarkAsRead && !isOffline;
    final images = _imageAttachments(item);
    final otherFiles = _nonImageAttachments(item);
    final cardColor = unread
        ? colorScheme.surfaceContainer
        : colorScheme.surfaceContainerLow;

    final bodyContent = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                _buildNewBadge(context),
              ],
            ],
          ),
          const SizedBox(height: 6),
          _buildMetaRow(context, item),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (item.errorMessage != null && item.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildErrorBanner(context, item.errorMessage!),
          ],
          if (otherFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final file in otherFiles)
                  FileChip(
                    file: DownloadableFile(
                      name: file.name,
                      url: file.downloadUrl,
                    ),
                    fileExtension: file.fileExtension,
                    offline: isOffline,
                  ),
              ],
            ),
          ],
          if (item.infoLink != null) ...[
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => openUrlModal(context, item.infoLink!.url),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(item.infoLink!.title),
            ),
          ],
        ],
      ),
    );

    return _CollapsiblePhoneCard(
      key: ValueKey('phone-card-${item.id}'),
      cardColor: cardColor,
      borderColor: unread ? colorScheme.primary : colorScheme.outlineVariant,
      maxHeightFactor: images.isNotEmpty ? (0.5 + 2 / 3) : (2 / 3),
      expanded: _expandedIds.contains(item.id),
      onExpand: () => setState(() => _expandedIds.add(item.id)),
      canAutoRead: canAutoRead,
      delay: _autoReadDelay,
      scrollTick: _scrollTick,
      onMarkAsRead: () => _markAsRead(item, parser, isOffline: isOffline),
      header: images.isNotEmpty
          ? _ImageAttachmentCarousel(images: images, offline: isOffline)
          : null,
      child: bodyContent,
    );
  }

  Widget _buildPhoneBody(
    BuildContext context,
    FileDistributionHome data,
    AppletDataSource<FileDistributionHome> parser,
    RefreshFunction? refresh,
    bool isOffline,
  ) {
    final visible = _filteredItems(data.items);
    final hasAnyItems = data.items.isNotEmpty;

    Widget list;
    if (!hasAnyItems) {
      list = _buildEmptyState(context);
    } else if (visible.isEmpty) {
      list = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          _buildFilterChips(context, data.items),
          const SizedBox(height: 48),
          _buildEmptyState(context, scrollable: false),
        ],
      );
    } else {
      list = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _scrollTick.value++;
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          itemCount: visible.length + 1,
          separatorBuilder: (_, index) =>
              SizedBox(height: index == 0 ? 4 : 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildFilterChips(context, data.items);
            }
            return _buildPhoneCard(
              context,
              visible[index - 1],
              parser,
              isOffline,
            );
          },
        ),
      );
    }

    return refresh != null
        ? RefreshIndicator(onRefresh: refresh, child: list)
        : list;
  }

  Widget _buildTabletBody(
    BuildContext context,
    FileDistributionHome data,
    AppletDataSource<FileDistributionHome> parser,
    RefreshFunction? refresh,
    bool isOffline,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final visible = _filteredItems(data.items);
    final hasAnyItems = data.items.isNotEmpty;

    FileDistributionItem? selected;
    if (visible.isNotEmpty) {
      selected = visible.firstWhere(
        (item) => item.id == _selectedId,
        orElse: () => visible.first,
      );
    }

    Widget masterList;
    if (!hasAnyItems) {
      masterList = _buildEmptyState(context);
    } else if (visible.isEmpty) {
      masterList = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        children: [
          _buildFilterChips(
            context,
            data.items,
            padding: const EdgeInsets.only(bottom: 8),
          ),
          const SizedBox(height: 32),
          _buildEmptyState(context, scrollable: false),
        ],
      );
    } else {
      masterList = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        itemCount: visible.length + 1,
        separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 4 : 4),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildFilterChips(
              context,
              data.items,
              padding: const EdgeInsets.only(bottom: 4),
            );
          }
          final item = visible[index - 1];
          final isSelected = selected?.id == item.id;
          final unread = _isUnread(item);
          final hasError =
              item.errorMessage != null && item.errorMessage!.isNotEmpty;
          final subtitleParts = <String>[
            if (hasError)
              l10n.fileDistributionErrorBadge
            else if (item.files.isNotEmpty)
              '${item.files.length} ${item.files.length == 1 ? l10n.file : l10n.files}'
            else
              l10n.fileDistributionOnlyNotice,
            if (item.validUntil != null) _dateFormat.format(item.validUntil!),
          ];

          return Material(
            color: isSelected
                ? colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                setState(() => _selectedId = item.id);
                _markAsRead(item, parser, isOffline: isOffline);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (unread) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: unread || isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? colorScheme.onSecondaryContainer
                                      : colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hasError
                            ? colorScheme.error
                            : (isSelected
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 320,
          child: Scaffold(
            appBar: _buildAppBar(context),
            body: refresh != null
                ? RefreshIndicator(onRefresh: refresh, child: masterList)
                : masterList,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: SafeArea(
            child: selected == null
                ? const SizedBox.shrink()
                : _buildTabletDetail(context, selected, parser, isOffline),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletDetail(
    BuildContext context,
    FileDistributionItem item,
    AppletDataSource<FileDistributionHome> parser,
    bool isOffline,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final unread = _isUnread(item);
    final canAutoRead = unread && item.canMarkAsRead && !isOffline;
    final images = _imageAttachments(item);
    final otherFiles = _nonImageAttachments(item);

    return _AutoReadOnFullVisibility(
      key: ValueKey('auto-read-tablet-${item.id}'),
      enabled: canAutoRead,
      delay: _autoReadDelay,
      scrollTick: _scrollTick,
      requireScrollViewport: false,
      onTrigger: () => _markAsRead(item, parser, isOffline: isOffline),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: canAutoRead
            ? () => _markAsRead(item, parser, isOffline: isOffline)
            : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (unread) ...[
                    const SizedBox(width: 12),
                    _buildNewBadge(context),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _buildMetaRow(context, item),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _ImageAttachmentCarousel(
                    images: images,
                    offline: isOffline,
                  ),
                ),
              ],
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: SelectableText(
                        item.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
              if (item.errorMessage != null &&
                  item.errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildErrorBanner(context, item.errorMessage!),
              ],
              if (otherFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final file in otherFiles)
                      FileChip(
                        file: DownloadableFile(
                          name: file.name,
                          url: file.downloadUrl,
                        ),
                        fileExtension: file.fileExtension,
                        offline: isOffline,
                      ),
                  ],
                ),
              ],
              if (item.infoLink != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => openUrlModal(context, item.infoLink!.url),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(item.infoLink!.title),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineCacheContextProvider);
    final AppletDataSource<FileDistributionHome> parser =
        widget.dataSource ?? ref.watch(fileDistributionParserProvider);
    final accountType =
        widget.accountType ??
        offline?.account.accountType ??
        ref.watch(activeAccountProvider)!.accountType!;

    return CombinedAppletBuilder<FileDistributionHome>(
      parser: parser,
      settings: widget.settings,
      phpUrl: fileDistributionDefinition.appletPhpUrl,
      settingsDefaults: fileDistributionDefinition.settingsDefaults,
      accountType: accountType,
      showErrorAppBar: true,
      loadingAppBar: _buildAppBar(context),
      builder: (context, data, accountType, settings, updateSetting, refresh) {
        final isOffline =
            offline != null ||
            parser.latestResponse?.contentStatus == ContentStatus.offline;
        final isSplitView =
            Responsive.isSplitView(context) && data.items.isNotEmpty;
        return Scaffold(
          appBar: isSplitView ? null : _buildAppBar(context),
          body: isSplitView
              ? _buildTabletBody(context, data, parser, refresh, isOffline)
              : _buildPhoneBody(context, data, parser, refresh, isOffline),
        );
      },
    );
  }
}

/// Triggers [onTrigger] after [child] has remained continuously and fully
/// visible within its enclosing [Scrollable] viewport for [delay].
class _AutoReadOnFullVisibility extends StatefulWidget {
  final bool enabled;
  final Duration delay;
  final ValueNotifier<int> scrollTick;
  final bool requireScrollViewport;
  final VoidCallback onTrigger;
  final Widget child;

  const _AutoReadOnFullVisibility({
    super.key,
    required this.enabled,
    required this.delay,
    required this.scrollTick,
    this.requireScrollViewport = true,
    required this.onTrigger,
    required this.child,
  });

  @override
  State<_AutoReadOnFullVisibility> createState() =>
      _AutoReadOnFullVisibilityState();
}

class _AutoReadOnFullVisibilityState extends State<_AutoReadOnFullVisibility> {
  Timer? _timer;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    widget.scrollTick.addListener(_scheduleCheck);
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(covariant _AutoReadOnFullVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollTick != widget.scrollTick) {
      oldWidget.scrollTick.removeListener(_scheduleCheck);
      widget.scrollTick.addListener(_scheduleCheck);
    }
    if (!widget.enabled) {
      _cancelTimer();
    } else if (!oldWidget.enabled) {
      _triggered = false;
      _scheduleCheck();
    }
  }

  @override
  void dispose() {
    widget.scrollTick.removeListener(_scheduleCheck);
    _cancelTimer();
    super.dispose();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleCheck() {
    if (!widget.enabled || _triggered) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (!mounted || !widget.enabled || _triggered) {
      _cancelTimer();
      return;
    }

    if (!widget.requireScrollViewport) {
      _startTimerIfNeeded();
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) {
      _cancelTimer();
      return;
    }

    final scrollable = Scrollable.maybeOf(context);
    final viewportBox = scrollable?.context.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize || !viewportBox.attached) {
      _cancelTimer();
      return;
    }

    final itemTopLeft = box.localToGlobal(Offset.zero);
    final itemBottom = itemTopLeft.dy + box.size.height;
    final viewportTopLeft = viewportBox.localToGlobal(Offset.zero);
    final viewportBottom = viewportTopLeft.dy + viewportBox.size.height;

    const tolerance = 2.0;
    final fullyVisible =
        itemTopLeft.dy >= viewportTopLeft.dy - tolerance &&
        itemBottom <= viewportBottom + tolerance;

    if (fullyVisible) {
      _startTimerIfNeeded();
    } else {
      _cancelTimer();
    }
  }

  void _startTimerIfNeeded() {
    if (_timer != null || _triggered) return;
    _timer = Timer(widget.delay, () {
      if (!mounted || !widget.enabled || _triggered) return;
      _triggered = true;
      widget.onTrigger();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Phone card that caps collapsed height at a 2:3 (width:height) ratio when
/// content exceeds that height. Tapping expands a collapsed card; the 8-second
/// auto-read timer only runs once the card fits or is expanded.
class _CollapsiblePhoneCard extends StatefulWidget {
  final Color cardColor;
  final Color borderColor;

  /// Collapsed max height as a multiple of card width (`2/3` = 3:2 without
  /// image banner, `0.5 + 2/3` = 2:1 image banner + 3:2 content area).
  final double maxHeightFactor;
  final bool expanded;
  final VoidCallback onExpand;
  final bool canAutoRead;
  final Duration delay;
  final ValueNotifier<int> scrollTick;
  final VoidCallback onMarkAsRead;
  final Widget? header;
  final Widget child;

  const _CollapsiblePhoneCard({
    super.key,
    required this.cardColor,
    required this.borderColor,
    required this.maxHeightFactor,
    required this.expanded,
    required this.onExpand,
    required this.canAutoRead,
    required this.delay,
    required this.scrollTick,
    required this.onMarkAsRead,
    this.header,
    required this.child,
  });

  @override
  State<_CollapsiblePhoneCard> createState() => _CollapsiblePhoneCardState();
}

class _CollapsiblePhoneCardState extends State<_CollapsiblePhoneCard> {
  double? _naturalHeight;

  void _onMeasuredHeight(double height) {
    if (_naturalHeight == height) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _naturalHeight = height);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCollapsedHeight =
            constraints.maxWidth * widget.maxHeightFactor;
        final needsExpansion =
            _naturalHeight != null && _naturalHeight! > maxCollapsedHeight + 1;
        final isCollapsed = needsExpansion && !widget.expanded;

        final bodyTap = isCollapsed
            ? widget.onExpand
            : (widget.canAutoRead ? widget.onMarkAsRead : null);

        final interactiveContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.header != null) widget.header!,
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: bodyTap,
                child: isCollapsed
                    ? widget.child
                    : SelectionArea(child: widget.child),
              ),
            ),
          ],
        );

        final measuredChild = _MeasureHeight(
          onHeight: _onMeasuredHeight,
          child: interactiveContent,
        );

        // When not expanded, cap height from frame 1 via ConstrainedBox +
        // non-scrollable SingleChildScrollView so ListView never sees a tall
        // card shrink after scroll-in (which would corrupt scrollOffset).
        final body = widget.expanded
            ? measuredChild
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxCollapsedHeight),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: measuredChild,
                    ),
                    if (isCollapsed)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 64,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  widget.cardColor.withValues(alpha: 0),
                                  widget.cardColor.withValues(alpha: 0.92),
                                  widget.cardColor,
                                ],
                                stops: const [0.0, 0.65, 1.0],
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 22,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );

        final card = Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: widget.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: widget.borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: body,
          ),
        );

        return _AutoReadOnFullVisibility(
          enabled: widget.canAutoRead && !isCollapsed && _naturalHeight != null,
          delay: widget.delay,
          scrollTick: widget.scrollTick,
          onTrigger: widget.onMarkAsRead,
          child: card,
        );
      },
    );
  }
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onHeight;

  const _MeasureHeight({required this.onHeight, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasureHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  ValueChanged<double> onHeight;
  double? _lastHeight;

  _RenderMeasureHeight(this.onHeight);

  @override
  void performLayout() {
    super.performLayout();
    final h = child?.size.height;
    if (h != null && h != _lastHeight) {
      _lastHeight = h;
      onHeight(h);
    }
  }
}

/// 2:1 image banner supporting 1 or more image attachments as a swipeable
/// carousel. Loads and caches images through [StorageManager] (the same cache
/// used by file tiles, DataStorage, and Substitutions) and opens tapped images
/// in the system viewer via [launchFile].
class _ImageAttachmentCarousel extends StatefulWidget {
  final List<FileDistributionFile> images;
  final bool offline;

  const _ImageAttachmentCarousel({
    required this.images,
    required this.offline,
  });

  @override
  State<_ImageAttachmentCarousel> createState() =>
      _ImageAttachmentCarouselState();
}

class _ImageAttachmentCarouselState extends State<_ImageAttachmentCarousel> {
  late final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final hasMultiple = images.length > 1;

    return AspectRatio(
      aspectRatio: 2 / 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) {
              final file = images[index];
              return _StorageCachedImage(
                file: file,
                offline: widget.offline,
                onTap: () => launchFile(
                  context,
                  DownloadableFile(name: file.name, url: file.downloadUrl),
                  () {},
                ),
              );
            },
          ),
          if (hasMultiple) ...[
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_pageIndex + 1} / ${images.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 5,
                  children: [
                    for (var i = 0; i < images.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: i == _pageIndex ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _pageIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StorageCachedImage extends ConsumerStatefulWidget {
  final FileDistributionFile file;
  final bool offline;
  final VoidCallback onTap;

  const _StorageCachedImage({
    required this.file,
    required this.offline,
    required this.onTap,
  });

  @override
  ConsumerState<_StorageCachedImage> createState() =>
      _StorageCachedImageState();
}

class _StorageCachedImageState extends ConsumerState<_StorageCachedImage> {
  String? _localPath;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant _StorageCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.downloadUrl != widget.file.downloadUrl ||
        oldWidget.file.name != widget.file.name) {
      Future.microtask(_load);
    }
  }

  Future<void> _load() async {
    final storage = ref.read(storageManagerProvider);
    if (storage == null) {
      if (mounted) setState(() { _loading = false; _failed = true; });
      return;
    }
    final url = widget.file.downloadUrl.toString();
    final name = widget.file.name;
    try {
      final exists = await storage.doesFileExist(url, name);
      if (exists) {
        final path = storage.resolvePath(url, name);
        if (mounted) setState(() { _localPath = path; _loading = false; });
        return;
      }
      if (widget.offline) {
        if (mounted) setState(() { _loading = false; _failed = true; });
        return;
      }
      final path = await storage.downloadFile(url, name);
      if (mounted) setState(() { _localPath = path; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_failed || _localPath == null) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(_localPath!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: () => showFileModal(
              context,
              DownloadableFile(
                name: widget.file.name,
                url: widget.file.downloadUrl,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
