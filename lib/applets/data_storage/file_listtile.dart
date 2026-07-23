import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart' hide FileInfo;

import '../../utils/file_operations.dart';
import '../../utils/file_icons.dart';
import '../../widgets/marquee.dart';

enum FileExists { yes, no, loading }

extension FileExistsExtension on FileExists {
  MaterialColor? get color => {
    FileExists.yes: Colors.green,
    FileExists.no: Colors.red,
    FileExists.loading: Colors.grey,
  }[this];
}

class FileListTile extends ConsumerStatefulWidget {
  final FileNode file;
  final BuildContext context;

  const FileListTile({super.key, required this.context, required this.file});

  @override
  ConsumerState<FileListTile> createState() => _FileListTileState();
}

class _FileListTileState extends ConsumerState<FileListTile> {
  var exists = FileExists.loading;

  @override
  void initState() {
    super.initState();
    Future.microtask(updateLocalFileStatus);
  }

  void updateLocalFileStatus() {
    final storage = ref.read(storageManagerProvider);
    if (storage == null) {
      setState(() => exists = FileExists.no);
      return;
    }
    storage.doesFileExist(widget.file.downloadUrl, widget.file.name).then((
      value,
    ) {
      if (!mounted) return;
      setState(() {
        exists = value ? FileExists.yes : FileExists.no;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: MarqueeWidget(child: Text(widget.file.name)),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.file.hinweis != null)
            Expanded(child: MarqueeWidget(child: Text(widget.file.hinweis!)))
          else
            Text(widget.file.groesse),
          const SizedBox(width: 5),
          Text(widget.file.aenderung),
        ],
      ),
      leading: Badge(
        backgroundColor: exists.color,
        child: Icon(getIconByFileExtension(widget.file.fileExtension)),
      ),
      onTap: () => launchFile(
        context,
        FileInfo(
          name: widget.file.name,
          size: widget.file.groesse,
          url: Uri.parse(widget.file.downloadUrl),
        ),
        updateLocalFileStatus,
      ),
      onLongPress: () {
        showFileModal(
          context,
          FileInfo(
            name: widget.file.name,
            url: Uri.parse(widget.file.downloadUrl),
            size: widget.file.groesse,
          ),
        );
      },
    );
  }
}

class SearchFileListTile extends ConsumerStatefulWidget {
  final String name;
  final String downloadUrl;
  final BuildContext context;

  const SearchFileListTile({
    super.key,
    required this.context,
    required this.name,
    required this.downloadUrl,
  });

  @override
  ConsumerState<SearchFileListTile> createState() => _SearchFileListTileState();
}

class _SearchFileListTileState extends ConsumerState<SearchFileListTile> {
  var exists = FileExists.loading;

  @override
  void initState() {
    super.initState();
    Future.microtask(updateLocalFileStatus);
  }

  void updateLocalFileStatus() {
    final storage = ref.read(storageManagerProvider);
    if (storage == null) {
      setState(() => exists = FileExists.no);
      return;
    }
    storage.doesFileExist(widget.downloadUrl, widget.name).then((value) {
      if (!mounted) return;
      setState(() {
        exists = value ? FileExists.yes : FileExists.no;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: MarqueeWidget(child: Text(widget.name)),
      leading: Badge(
        backgroundColor: exists.color,
        child: Icon(getIconByFileExtension(widget.name.split('.').last)),
      ),
      onTap: () => launchFile(
        context,
        FileInfo(name: widget.name, url: Uri.parse(widget.downloadUrl)),
        updateLocalFileStatus,
      ),
      onLongPress: () => showFileModal(
        context,
        FileInfo(
          name: widget.name,
          url: Uri.parse(widget.downloadUrl),
          size: "",
        ),
      ),
    );
  }
}
