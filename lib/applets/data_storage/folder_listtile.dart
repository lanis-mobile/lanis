import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';

class FolderListTile extends ListTile {
  final FolderNode folder;
  final BuildContext context;

  const FolderListTile({
    super.key,
    required this.context,
    required this.folder,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(folder.name),
      subtitle: folder.desc.trim() != ''
          ? Text(folder.desc, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
      leading: const Icon(Icons.folder_outlined),
      onTap: () {
        final title = Uri.encodeComponent(folder.name);
        context.push('/common/storage/folder/${folder.id}?title=$title');
      },
    );
  }
}
