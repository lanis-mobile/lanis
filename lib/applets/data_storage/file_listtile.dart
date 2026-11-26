import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

import '../../utils/file_icons.dart';
import '../../utils/file_operations.dart';
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

  const FileListTile({super.key, required this.file});

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

  @override
  void didUpdateWidget(covariant FileListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.downloadUrl != widget.file.downloadUrl ||
        oldWidget.file.name != widget.file.name) {
      exists = FileExists.loading;
      Future.microtask(updateLocalFileStatus);
    }
  }

  void updateLocalFileStatus() {
    final storage = ref.read(storageManagerProvider);
    if (storage == null) {
      setState(() => exists = FileExists.no);
      return;
    }
    final targetUrl = widget.file.downloadUrl;
    final targetName = widget.file.name;
    storage.doesFileExist(targetUrl, targetName).then((value) {
      if (!mounted ||
          widget.file.downloadUrl != targetUrl ||
          widget.file.name != targetName) {
        return;
      }
      setState(() {
        exists = value ? FileExists.yes : FileExists.no;
      });
    });
  }

  String _formatDate(BuildContext context) {
    final modifiedAt = widget.file.modifiedAt;
    if (modifiedAt != null) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      final hasTime = widget.file.aenderung.contains(':');
      final fmt = hasTime
          ? DateFormat.yMd(locale).add_Hm()
          : DateFormat.yMd(locale);
      return fmt.format(modifiedAt);
    }
    return widget.file.aenderung;
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _formatDate(context);
    final hinweis = widget.file.hinweis?.trim();
    final hasHinweis = hinweis != null && hinweis.isNotEmpty;
    final hasSize = widget.file.groesse.trim().isNotEmpty;
    final hasDate = dateText.trim().isNotEmpty;

    Widget? subtitle;
    if (hasHinweis || hasSize || hasDate) {
      subtitle = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (hasHinweis)
            Expanded(child: MarqueeWidget(child: Text(hinweis)))
          else if (hasSize)
            Text(widget.file.groesse),
          if ((hasHinweis || hasSize) && hasDate) const SizedBox(width: 8),
          if (hasDate) Text(dateText),
        ],
      );
    }

    return ListTile(
      title: MarqueeWidget(child: Text(widget.file.name)),
      subtitle: subtitle,
      leading: Badge(
        backgroundColor: exists.color,
        child: Icon(getIconByFileExtension(widget.file.fileExtension)),
      ),
      onTap: () => launchFile(
        context,
        DownloadableFile(
          name: widget.file.name,
          size: widget.file.groesse,
          url: Uri.parse(widget.file.downloadUrl),
        ),
        updateLocalFileStatus,
      ),
      onLongPress: () {
        showFileModal(
          context,
          DownloadableFile(
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
  final String? hinweis;
  final String? extension;

  const SearchFileListTile({
    super.key,
    required this.name,
    required this.downloadUrl,
    this.hinweis,
    this.extension,
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

  @override
  void didUpdateWidget(covariant SearchFileListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.downloadUrl != widget.downloadUrl ||
        oldWidget.name != widget.name) {
      exists = FileExists.loading;
      Future.microtask(updateLocalFileStatus);
    }
  }

  void updateLocalFileStatus() {
    final storage = ref.read(storageManagerProvider);
    if (storage == null) {
      setState(() => exists = FileExists.no);
      return;
    }
    final targetUrl = widget.downloadUrl;
    final targetName = widget.name;
    storage.doesFileExist(targetUrl, targetName).then((value) {
      if (!mounted ||
          widget.downloadUrl != targetUrl ||
          widget.name != targetName) {
        return;
      }
      setState(() {
        exists = value ? FileExists.yes : FileExists.no;
      });
    });
  }

  String get _fileExtension {
    final ext = widget.extension?.trim();
    if (ext != null && ext.isNotEmpty) return ext;
    final dot = widget.name.lastIndexOf('.');
    return dot > 0 && dot < widget.name.length - 1
        ? widget.name.substring(dot + 1)
        : '';
  }

  @override
  Widget build(BuildContext context) {
    final hinweis = widget.hinweis?.trim();
    return ListTile(
      title: MarqueeWidget(child: Text(widget.name)),
      subtitle: hinweis != null && hinweis.isNotEmpty
          ? Text(hinweis, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      leading: Badge(
        backgroundColor: exists.color,
        child: Icon(getIconByFileExtension(_fileExtension)),
      ),
      onTap: () => launchFile(
        context,
        DownloadableFile(name: widget.name, url: Uri.parse(widget.downloadUrl)),
        updateLocalFileStatus,
      ),
      onLongPress: () => showFileModal(
        context,
        DownloadableFile(
          name: widget.name,
          url: Uri.parse(widget.downloadUrl),
          size: "",
        ),
      ),
    );
  }
}
