import 'package:go_router/go_router.dart';
import 'package:lanis/applets/data_storage/data_storage_ui.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

class FolderListTile extends StatelessWidget {
  final FolderNode folder;
  final List<String> parentPath;

  const FolderListTile({
    super.key,
    required this.folder,
    this.parentPath = const [],
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customColor = parseFolderColor(folder.colorHex);
    final desc = folder.desc.trim();

    final counts = <String>[
      if (folder.subfolders > 0) l10n.dataStorageSubfolderCount(folder.subfolders),
      if (folder.fileCount != null && folder.fileCount! > 0)
        l10n.dataStorageFileCount(folder.fileCount!),
    ];
    final countText = counts.join(' · ');

    Widget? subtitle;
    if (desc.isNotEmpty && countText.isNotEmpty) {
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            countText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (desc.isNotEmpty) {
      subtitle = Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis);
    } else if (countText.isNotEmpty) {
      subtitle = Text(
        countText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return ListTile(
      title: Text(folder.name),
      subtitle: subtitle,
      leading: Icon(
        customColor != null ? Icons.folder : Icons.folder_outlined,
        color: customColor,
      ),
      onTap: () {
        context.push(
          buildFolderRouteUri(
            folder.id,
            title: folder.name,
            parentPath: parentPath,
          ),
        );
      },
    );
  }
}
