import 'package:go_router/go_router.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

enum DataStorageSortOrder {
  nameAsc,
  nameDesc,
  dateDesc,
  dateAsc,
  sizeDesc,
  sizeAsc,
}

List<FolderNode> sortDataStorageFolders(
  List<FolderNode> folders,
  DataStorageSortOrder order,
) {
  final copy = List<FolderNode>.of(folders);
  copy.sort((a, b) {
    final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return order == DataStorageSortOrder.nameDesc ? -cmp : cmp;
  });
  return copy;
}

List<FileNode> sortDataStorageFiles(
  List<FileNode> files,
  DataStorageSortOrder order,
) {
  final copy = List<FileNode>.of(files);
  copy.sort((a, b) {
    int cmp;
    switch (order) {
      case DataStorageSortOrder.nameAsc:
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case DataStorageSortOrder.nameDesc:
        cmp = b.name.toLowerCase().compareTo(a.name.toLowerCase());
      case DataStorageSortOrder.dateDesc:
        cmp = _compareNullable(b.modifiedAt, a.modifiedAt);
      case DataStorageSortOrder.dateAsc:
        cmp = _compareNullable(a.modifiedAt, b.modifiedAt);
      case DataStorageSortOrder.sizeDesc:
        cmp = _compareNullable(b.sizeBytes, a.sizeBytes);
      case DataStorageSortOrder.sizeAsc:
        cmp = _compareNullable(a.sizeBytes, b.sizeBytes);
    }
    if (cmp != 0) return cmp;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return copy;
}

int _compareNullable<T extends Comparable<Object>>(T? a, T? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

/// Parses an SPH folder hex color (`#rrggbb` or `#rgb`), returning `null` for
/// SPH's default black (`#000000`) so folders respect Light/Dark theme colors.
Color? parseFolderColor(String? hex) {
  if (hex == null) return null;
  var cleaned = hex.trim().toLowerCase();
  if (cleaned.startsWith('#')) {
    cleaned = cleaned.substring(1);
  }
  if (cleaned.length == 3) {
    cleaned = cleaned.split('').map((c) => '$c$c').join();
  }
  if (cleaned.length != 6) return null;
  if (cleaned == '000000') return null;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

String buildFolderRouteUri(
  int folderId, {
  required String title,
  List<String> parentPath = const [],
}) {
  return Uri(
    path: '/common/storage/folder/$folderId',
    queryParameters: <String, dynamic>{
      if (title.isNotEmpty) 'title': title,
      if (parentPath.isNotEmpty) 'p': parentPath,
    },
  ).toString();
}

/// Displays a directory breadcrumb path in an AppBar subtitle, keeping the
/// closest parent segments visible by collapsing leading segments into `… › `.
class DirectoryPathSubtitle extends StatelessWidget {
  final List<String> segments;
  final TextStyle? style;
  final TextAlign textAlign;

  const DirectoryPathSubtitle({
    super.key,
    required this.segments,
    this.style,
    this.textAlign = TextAlign.start,
  });

  static const _separator = ' › ';
  static const _ellipsisPrefix = '… › ';

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    final effectiveStyle =
        style ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final text = _fitTrailingSegments(
          segments: segments,
          maxWidth: maxWidth,
          style: effectiveStyle,
          textDirection: textDirection,
          textScaler: textScaler,
        );
        return Text(
          text,
          style: effectiveStyle,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  static String _fitTrailingSegments({
    required List<String> segments,
    required double maxWidth,
    required TextStyle? style,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final full = segments.join(_separator);
    if (!maxWidth.isFinite || maxWidth <= 0) return full;

    bool fits(String candidate) {
      final painter = TextPainter(
        text: TextSpan(text: candidate, style: style),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      return painter.width <= maxWidth;
    }

    if (fits(full) || segments.length == 1) return full;

    for (var start = 1; start < segments.length; start++) {
      final candidate = '$_ellipsisPrefix${segments.sublist(start).join(_separator)}';
      if (fits(candidate)) return candidate;
    }

    return '$_ellipsisPrefix${segments.last}';
  }
}

class DataStorageEmptyFolderPlaceholder extends StatelessWidget {
  const DataStorageEmptyFolderPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 96),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 64, color: muted),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).dataStorageEmptyFolder,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DataStorageSortButton extends StatelessWidget {
  final DataStorageSortOrder selected;
  final ValueChanged<DataStorageSortOrder> onSelected;
  final bool includeDateAndSize;

  const DataStorageSortButton({
    super.key,
    required this.selected,
    required this.onSelected,
    this.includeDateAndSize = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectiveSelected = !includeDateAndSize &&
            selected != DataStorageSortOrder.nameAsc &&
            selected != DataStorageSortOrder.nameDesc
        ? DataStorageSortOrder.nameAsc
        : selected;
    return PopupMenuButton<DataStorageSortOrder>(
      tooltip: l10n.dataStorageSort,
      icon: const Icon(Icons.sort),
      initialValue: effectiveSelected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        _item(
          context,
          DataStorageSortOrder.nameAsc,
          l10n.dataStorageSortNameAsc,
          effectiveSelected,
        ),
        _item(
          context,
          DataStorageSortOrder.nameDesc,
          l10n.dataStorageSortNameDesc,
          effectiveSelected,
        ),
        if (includeDateAndSize) ...[
          _item(
            context,
            DataStorageSortOrder.dateDesc,
            l10n.dataStorageSortDateDesc,
            effectiveSelected,
          ),
          _item(
            context,
            DataStorageSortOrder.dateAsc,
            l10n.dataStorageSortDateAsc,
            effectiveSelected,
          ),
          _item(
            context,
            DataStorageSortOrder.sizeDesc,
            l10n.dataStorageSortSizeDesc,
            effectiveSelected,
          ),
          _item(
            context,
            DataStorageSortOrder.sizeAsc,
            l10n.dataStorageSortSizeAsc,
            effectiveSelected,
          ),
        ],
      ],
    );
  }

  PopupMenuItem<DataStorageSortOrder> _item(
    BuildContext context,
    DataStorageSortOrder value,
    String label,
    DataStorageSortOrder effectiveSelected,
  ) {
    final isSelected = value == effectiveSelected;
    return PopupMenuItem<DataStorageSortOrder>(
      value: value,
      child: Row(
        children: [
          Icon(
            Icons.check,
            size: 18,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

Future<void> showDataStorageBreadcrumbSheet(
  BuildContext context, {
  required List<FolderBreadcrumb> breadcrumbs,
  required int currentNodeId,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.dataStoragePathTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: breadcrumbs.length,
                itemBuilder: (itemContext, index) {
                  final crumb = breadcrumbs[index];
                  final label = crumb.id == 0 ? l10n.storage : crumb.name;
                  final isCurrent = crumb.id == currentNodeId;
                  return ListTile(
                    contentPadding: EdgeInsets.only(
                      left: 16.0 + index * 12.0,
                      right: 16.0,
                    ),
                    leading: Icon(
                      isCurrent
                          ? Icons.folder_open
                          : (crumb.id == 0
                              ? Icons.home_outlined
                              : Icons.folder_outlined),
                      color: isCurrent
                          ? Theme.of(itemContext).colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      label,
                      style: isCurrent
                          ? TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(itemContext).colorScheme.primary,
                            )
                          : null,
                    ),
                    onTap: isCurrent
                        ? () => Navigator.of(sheetContext).pop()
                        : () {
                            Navigator.of(sheetContext).pop();
                            if (crumb.id == 0) {
                              context.go('/common/storage/home');
                              return;
                            }
                            final targetPath = '/common/storage/folder/${crumb.id}';
                            final matches = GoRouter.of(
                              context,
                            ).routerDelegate.currentConfiguration.matches;
                            final existingIndex = matches.lastIndexWhere(
                              (m) => Uri.parse(m.matchedLocation).path == targetPath,
                            );
                            if (existingIndex >= 0 &&
                                existingIndex < matches.length - 1) {
                              final pops = matches.length - 1 - existingIndex;
                              final nav = Navigator.of(context);
                              for (var i = 0; i < pops && nav.canPop(); i++) {
                                nav.pop();
                              }
                            } else {
                              final parentNames = breadcrumbs
                                  .take(index)
                                  .where((b) => b.id != 0)
                                  .map((b) => b.name)
                                  .toList(growable: false);
                              context.pushReplacement(
                                buildFolderRouteUri(
                                  crumb.id,
                                  title: crumb.name,
                                  parentPath: parentNames,
                                ),
                              );
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
