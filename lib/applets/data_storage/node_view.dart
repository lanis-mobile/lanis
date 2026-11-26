import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/data_storage/data_storage_ui.dart';
import 'package:lanis/applets/data_storage/folder_listtile.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

import 'file_listtile.dart';

class DataStorageNodeView extends ConsumerStatefulWidget {
  final int nodeID;
  final String title;
  final List<String> initialPath;

  const DataStorageNodeView({
    super.key,
    required this.nodeID,
    required this.title,
    this.initialPath = const [],
  });

  @override
  ConsumerState<DataStorageNodeView> createState() =>
      _DataStorageNodeViewState();
}

class _DataStorageNodeViewState extends ConsumerState<DataStorageNodeView> {
  var loading = true;
  var error = false;
  DataStorageNode? node;
  var sortOrder = DataStorageSortOrder.nameAsc;

  @override
  void initState() {
    super.initState();
    Future.microtask(loadItems);
  }

  Future<void> loadItems() async {
    try {
      final fetched = await ref
          .read(dataStorageParserProvider)
          .getNodeDetails(widget.nodeID);
      if (!mounted) return;
      setState(() {
        node = fetched;
        error = false;
        loading = false;
      });
    } on LanisException {
      if (!mounted) return;
      setState(() {
        error = true;
        loading = false;
      });
    }
  }

  String _resolvedFolderName() {
    final serverName = node?.name.trim() ?? '';
    if (serverName.isNotEmpty) return serverName;
    return widget.title.trim();
  }

  List<String> _resolvedPathSegments() {
    final breadcrumbs = node?.breadcrumbs ?? const <FolderBreadcrumb>[];
    final nonRoot = [
      for (final crumb in breadcrumbs)
        if (crumb.id != 0) crumb.name,
    ];
    if (nonRoot.isNotEmpty) return nonRoot;

    final folderName = _resolvedFolderName();
    return [
      ...widget.initialPath,
      if (folderName.isNotEmpty) folderName,
    ];
  }

  List<Widget> getListTiles() {
    final currentNode = node;
    if (currentNode == null) return const [];

    final nextParentPath = _resolvedPathSegments();
    final sortedFolders = sortDataStorageFolders(currentNode.folders, sortOrder);
    final sortedFiles = sortDataStorageFiles(currentNode.files, sortOrder);

    return [
      for (final folder in sortedFolders)
        FolderListTile(
          key: ValueKey('folder_${folder.id}'),
          folder: folder,
          parentPath: nextParentPath,
        ),
      for (final file in sortedFiles)
        FileListTile(key: ValueKey('file_${file.id}'), file: file),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final centerTitle =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final appBarTitle = AppLocalizations.of(context).storage;
    final pathSegments = _resolvedPathSegments();
    final breadcrumbs = node?.breadcrumbs ?? const <FolderBreadcrumb>[];

    Widget titleWidget = pathSegments.isEmpty
        ? Text(
            appBarTitle,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centerTitle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                appBarTitle,
                textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              DirectoryPathSubtitle(
                segments: pathSegments,
                textAlign: centerTitle ? TextAlign.center : TextAlign.start,
              ),
            ],
          );

    if (breadcrumbs.length > 1) {
      titleWidget = InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDataStorageBreadcrumbSheet(
          context,
          breadcrumbs: breadcrumbs,
          currentNodeId: widget.nodeID,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: titleWidget,
        ),
      );
    }

    final tiles = getListTiles();

    return Scaffold(
      appBar: AppBar(
        centerTitle: centerTitle,
        title: titleWidget,
        actions: [
          DataStorageSortButton(
            selected: sortOrder,
            onSelected: (value) => setState(() => sortOrder = value),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 100),
                  const SizedBox(height: 10),
                  Text(AppLocalizations.of(context).couldNotLoadFiles),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadItems,
              child: tiles.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [DataStorageEmptyFolderPlaceholder()],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: tiles,
                    ),
            ),
    );
  }
}
