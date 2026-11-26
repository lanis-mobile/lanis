import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/data_storage/data_storage_ui.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

import 'file_listtile.dart';
import 'folder_listtile.dart';

enum _RootViewSection { all, newFiles }

class DataStorageRootView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  const DataStorageRootView({super.key, this.openDrawerCb});

  @override
  ConsumerState<DataStorageRootView> createState() =>
      _DataStorageRootViewState();
}

class _DataStorageRootViewState extends ConsumerState<DataStorageRootView> {
  var loading = true;
  var error = false;
  DataStorageNode? node;
  var sortOrder = DataStorageSortOrder.nameAsc;
  var _section = _RootViewSection.all;
  final SearchController searchController = SearchController();

  @override
  void initState() {
    super.initState();
    Future.microtask(loadItems);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadItems() async {
    try {
      final fetched = await ref.read(dataStorageParserProvider).getRootDetails();
      if (!mounted) return;
      setState(() {
        node = fetched;
        if (fetched.newFiles.isEmpty) {
          _section = _RootViewSection.all;
        }
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

  List<Widget> getListTiles(BuildContext context) {
    final currentNode = node;
    if (currentNode == null) return const [];

    final hasNewFiles = currentNode.newFiles.isNotEmpty;
    final activeSection =
        hasNewFiles ? _section : _RootViewSection.all;

    final tiles = <Widget>[
      if (hasNewFiles)
        _RootSectionChips(
          selected: activeSection,
          newFilesCount: currentNode.newFiles.length,
          onSelected: (section) => setState(() => _section = section),
        ),
    ];

    if (activeSection == _RootViewSection.newFiles) {
      final sortedNewFiles = sortDataStorageFiles(
        currentNode.newFiles,
        sortOrder,
      );
      tiles.addAll([
        for (final file in sortedNewFiles)
          SearchFileListTile(
            key: ValueKey('new_file_${file.id}'),
            name: file.name,
            downloadUrl: file.downloadUrl,
            hinweis: file.hinweis,
            extension: file.extension,
          ),
      ]);
      return tiles;
    }

    final sortedFolders = sortDataStorageFolders(currentNode.folders, sortOrder);
    final sortedFiles = sortDataStorageFiles(currentNode.files, sortOrder);
    if (sortedFolders.isEmpty && sortedFiles.isEmpty) {
      tiles.add(const DataStorageEmptyFolderPlaceholder());
      return tiles;
    }
    tiles.addAll([
      for (final folder in sortedFolders)
        FolderListTile(key: ValueKey('folder_${folder.id}'), folder: folder),
      for (final file in sortedFiles)
        FileListTile(key: ValueKey('file_${file.id}'), file: file),
    ]);
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final centerTitle =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final hasNewFiles = (node?.newFiles ?? const []).isNotEmpty;
    final activeSection =
        hasNewFiles ? _section : _RootViewSection.all;
    final tiles = getListTiles(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: centerTitle,
        title: Text(AppLocalizations.of(context).storage),
        leading: widget.openDrawerCb != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              )
            : null,
        actions: [
          DataStorageSortButton(
            selected: sortOrder,
            includeDateAndSize: activeSection != _RootViewSection.newFiles,
            onSelected: (value) => setState(() => sortOrder = value),
          ),
          const AsyncSearchAnchor(),
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
                  Text(AppLocalizations.of(context).couldNotLoadDataStorage),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadItems,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: tiles,
              ),
            ),
    );
  }
}

class _RootSectionChips extends StatelessWidget {
  final _RootViewSection selected;
  final int newFilesCount;
  final ValueChanged<_RootViewSection> onSelected;

  const _RootSectionChips({
    required this.selected,
    required this.newFilesCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: Text(l10n.dataStorageAll),
            selected: selected == _RootViewSection.all,
            onSelected: (_) => onSelected(_RootViewSection.all),
          ),
          ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.dataStorageNewFiles),
                const SizedBox(width: 6),
                Badge.count(count: newFilesCount),
              ],
            ),
            selected: selected == _RootViewSection.newFiles,
            onSelected: (_) => onSelected(_RootViewSection.newFiles),
          ),
        ],
      ),
    );
  }
}

class AsyncSearchAnchor extends ConsumerStatefulWidget {
  const AsyncSearchAnchor({super.key});

  @override
  ConsumerState<AsyncSearchAnchor> createState() => _AsyncSearchAnchorState();
}

class _AsyncSearchAnchorState extends ConsumerState<AsyncSearchAnchor> {
  int _searchRequestId = 0;
  late Iterable<Widget> _lastOptions = <Widget>[];

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).asData?.value == null) {
      return const IconButton(
        icon: Icon(Icons.search),
        onPressed: null,
      );
    }
    final parser = ref.watch(dataStorageParserProvider);
    return SearchAnchor(
      builder: (BuildContext context, SearchController controller) {
        return IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            controller.openView();
          },
        );
      },
      suggestionsBuilder:
          (BuildContext context, SearchController controller) async {
            final requestId = ++_searchRequestId;
            final query = controller.text;
            dynamic options;
            try {
              options = await parser.searchFiles(query);
            } catch (_) {
              if (requestId != _searchRequestId) {
                return _lastOptions;
              }
              _lastOptions = <Widget>[
                ListTile(
                  title: Text(
                    context.mounted
                        ? AppLocalizations.of(context).errorOccurred
                        : 'Error',
                  ),
                ),
              ];
              return _lastOptions;
            }

            if (requestId != _searchRequestId || !context.mounted) {
              return _lastOptions;
            }

            final items = options is List ? options : const <dynamic>[];
            _lastOptions = <Widget>[
              for (final item in items)
                if (item is Map)
                  SearchFileListTile(
                    name: '${item["text"] ?? ''}',
                    downloadUrl:
                        "https://start.schulportal.hessen.de/dateispeicher.php?a=download&f=${item["id"]}",
                  ),
            ];

            if (_lastOptions.isEmpty) {
              _lastOptions = <Widget>[
                ListTile(
                  title: Text(
                    context.mounted
                        ? AppLocalizations.of(context).noResults
                        : 'Error',
                  ),
                ),
              ];
            }

            return _lastOptions;
          },
    );
  }
}
