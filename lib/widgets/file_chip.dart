import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/utils/file_icons.dart';
import 'package:lanis/utils/file_operations.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

/// Shared Material 3 file chip used by Lessons and File Distribution.
///
/// Tapping opens/downloads the file via [launchFile]; long-pressing opens
/// [showFileModal].
class FileChip extends ConsumerStatefulWidget {
  final DownloadableFile file;
  final String? fileExtension;
  final bool offline;

  const FileChip({
    super.key,
    required this.file,
    this.fileExtension,
    this.offline = false,
  });

  @override
  ConsumerState<FileChip> createState() => _FileChipState();
}

class _FileChipState extends ConsumerState<FileChip> {
  bool _isLocal = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkLocalStatus);
  }

  @override
  void didUpdateWidget(covariant FileChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.url != widget.file.url ||
        oldWidget.file.name != widget.file.name) {
      Future.microtask(_checkLocalStatus);
    }
  }

  void _checkLocalStatus() {
    final storage = ref.read(storageManagerProvider);
    final url = widget.file.url?.toString();
    final name = widget.file.name;
    if (storage == null || url == null || name == null) return;
    storage.doesFileExist(url, name).then((exists) {
      if (mounted && exists != _isLocal) {
        setState(() => _isLocal = exists);
      }
    });
  }

  String get _extension {
    if (widget.fileExtension != null) return widget.fileExtension!;
    final name = widget.file.name ?? '';
    final dot = name.lastIndexOf('.');
    return dot > 0 && dot < name.length - 1 ? name.substring(dot + 1) : '';
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.offline && !_isLocal;
    final label = widget.file.name ?? '...';

    return GestureDetector(
      onLongPress: disabled ? null : () => showFileModal(context, widget.file),
      child: ActionChip(
        avatar: Icon(getIconByFileExtension(_extension), size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        onPressed: disabled
            ? null
            : () => launchFile(context, widget.file, _checkLocalStatus),
      ),
    );
  }
}
