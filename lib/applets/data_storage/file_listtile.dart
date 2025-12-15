import 'package:flutter/material.dart';

import '../../core/sph/sph.dart';
import '../../models/datastorage.dart';
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

class FileListTile extends StatefulWidget {
  final FileNode file;
  final BuildContext context;

  const FileListTile({super.key, required this.context, required this.file});

  @override
  State<FileListTile> createState() => _FileListTileState();
}

class _FileListTileState extends State<FileListTile> {
  var exists = FileExists.loading;

  @override
  void initState() {
    super.initState();
    updateLocalFileStatus();
  }

  void updateLocalFileStatus() {
    sph!.storage
        .doesFileExist(widget.file.downloadUrl, widget.file.name)
        .then((value) {
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
            Expanded(
                child: MarqueeWidget(
              child: Text(widget.file.hinweis!),
            ))
          else
            Text(widget.file.groesse),
          const SizedBox(width: 5),
          Text(widget.file.aenderung),
        ],
      ),
      leading: Badge(
          backgroundColor: exists.color,
          child: Icon(getIconByFileExtension(widget.file.fileExtension))),
      onTap: () => launchFile(
          context,
          FileInfo(
            name: widget.file.name,
            size: widget.file.groesse,
            url: Uri.parse(widget.file.downloadUrl),
          ),
          updateLocalFileStatus),
      onLongPress: () {
        showFileModal(
            context,
            FileInfo(
              name: widget.file.name,
              url: Uri.parse(widget.file.downloadUrl),
              size: widget.file.groesse,
            ));
      },
    );
  }
}

class SearchFileListTile extends StatefulWidget {
  final String name;
  final String downloadUrl;
  final BuildContext context;

  const SearchFileListTile(
      {super.key,
      required this.context,
      required this.name,
      required this.downloadUrl});

  @override
  State<SearchFileListTile> createState() => _SearchFileListTileState();
}

class _SearchFileListTileState extends State<SearchFileListTile> {
  var exists = FileExists.loading;

  @override
  void initState() {
    super.initState();
    updateLocalFileStatus();
  }

  void updateLocalFileStatus() {
    sph!.storage.doesFileExist(widget.downloadUrl, widget.name).then((value) {
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
          FileInfo(
            name: widget.name,
            url: Uri.parse(widget.downloadUrl),
          ),
          updateLocalFileStatus),
      onLongPress: () => showFileModal(
          context,
          FileInfo(
            name: widget.name,
            url: Uri.parse(widget.downloadUrl),
            size: "",
          )),
    );
  }
}
