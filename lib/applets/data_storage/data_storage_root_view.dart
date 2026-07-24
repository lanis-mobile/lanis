import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';

import 'file_listtile.dart';
import 'folder_listtile.dart';

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
  late List<FileNode> files;
  late List<FolderNode> folders;
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

  void loadItems() async {
    try {
      var items = await ref.read(dataStorageParserProvider).getRoot();
      if (!mounted) return;
      var (fileList, folderList) = items;
      files = fileList;
      folders = folderList;

      setState(() {
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

  List<Widget> getListTiles() {
    var listTiles = <Widget>[];

    for (var folder in folders) {
      listTiles.add(FolderListTile(context: context, folder: folder));
    }
    for (var file in files) {
      listTiles.add(FileListTile(context: context, file: file));
    }
    return listTiles;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).storage),
        leading: widget.openDrawerCb != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              )
            : null,
        actions: const [AsyncSearchAnchor()],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : error
          ? Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 100),
                  SizedBox(height: 10),
                  Text(AppLocalizations.of(context).couldNotLoadDataStorage),
                ],
              ),
            )
          : ListView(children: getListTiles()),
    );
  }
}

class AsyncSearchAnchor extends ConsumerStatefulWidget {
  const AsyncSearchAnchor({super.key});

  @override
  ConsumerState<AsyncSearchAnchor> createState() => _AsyncSearchAnchorState();
}

class _AsyncSearchAnchorState extends ConsumerState<AsyncSearchAnchor> {
  String? _searchingWithQuery;
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
            _searchingWithQuery = controller.text;
            var options = await parser.searchFiles(_searchingWithQuery ?? '');

            if (_searchingWithQuery != controller.text) {
              return _lastOptions;
            }

            _lastOptions = List<Widget>.generate(options?.length ?? 0, (
              int index,
            ) {
              final Map item = options[index];
              return SearchFileListTile(
                context: context,
                name: item["text"],
                downloadUrl:
                    "https://start.schulportal.hessen.de/dateispeicher.php?a=download&f=${item["id"]}",
              );
            });

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
