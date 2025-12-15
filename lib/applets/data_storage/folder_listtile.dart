import 'package:flutter/material.dart';

import '../../models/datastorage.dart';
import 'node_view.dart';

class FolderListTile extends ListTile {
  final FolderNode folder;
  final BuildContext context;

  const FolderListTile(
      {super.key, required this.context, required this.folder});

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(folder.name),
        subtitle: folder.desc.trim() != ''
            ? Text(
                folder.desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        leading: const Icon(Icons.folder_outlined),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DataStorageNodeView(nodeID: folder.id, title: folder.name),
            ),
          );
        });
  }
}
