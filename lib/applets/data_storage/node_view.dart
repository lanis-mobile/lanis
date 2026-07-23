import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/data_storage/folder_listtile.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';

import 'file_listtile.dart';

class DataStorageNodeView extends ConsumerStatefulWidget {
  final int nodeID;
  final String title;

  const DataStorageNodeView({
    super.key,
    required this.nodeID,
    required this.title,
  });

  @override
  ConsumerState<DataStorageNodeView> createState() =>
      _DataStorageNodeViewState();
}

class _DataStorageNodeViewState extends ConsumerState<DataStorageNodeView> {
  var loading = true;
  var error = false;
  late List<FileNode> files;
  late List<FolderNode> folders;

  @override
  void initState() {
    super.initState();
    Future.microtask(loadItems);
  }

  void loadItems() async {
    try {
      final (fileList, folderList) = await ref
          .read(dataStorageParserProvider)
          .getNode(widget.nodeID);
      files = fileList;
      folders = folderList;

      setState(() {
        loading = false;
      });
    } on LanisException {
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
      appBar: AppBar(title: Text(widget.title)),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : error
          ? Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 100),
                  SizedBox(height: 10),
                  Text(AppLocalizations.of(context).couldNotLoadFiles),
                ],
              ),
            )
          : ListView(children: getListTiles()),
    );
  }
}
