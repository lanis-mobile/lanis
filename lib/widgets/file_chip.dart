import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/features/offline/cache_context.dart';
import 'package:lanis/utils/file_icons.dart';
import 'package:lanis/utils/file_operations.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_file/open_file.dart';

/// Shared Material 3 file chip used by Lessons and File Distribution.
///
/// Tapping opens/downloads the file via [launchFile] (or directly from local
/// cache when offline); long-pressing opens [showFileModal]. When offline and
/// the file is not cached locally, the chip is disabled.
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
  String? _offlineCachedPath;

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
    final url = widget.file.url?.toString();
    final name = widget.file.name;
    if (url == null || name == null) return;

    final offlineContext = ref.read(offlineCacheContextProvider);
    if (offlineContext != null) {
      final path = offlineContext.cachedDocument(url, name);
      if (mounted) {
        setState(() {
          _offlineCachedPath = path;
          _isLocal = path != null;
        });
      }
      return;
    }

    final storage = ref.read(storageManagerProvider);
    if (storage == null) return;
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
    final offlineContext = ref.watch(offlineCacheContextProvider);
    final isDisconnected = offlineContext == null &&
        ref.watch(connectionStatusProvider).asData?.value ==
            ConnectionStatus.disconnected;
    final isOffline =
        widget.offline || offlineContext != null || isDisconnected;
    final disabled = isOffline && !_isLocal;
    final label = widget.file.name ?? '...';

    return GestureDetector(
      onLongPress: disabled || offlineContext != null
          ? null
          : () => showFileModal(context, widget.file),
      child: ActionChip(
        avatar: Icon(getIconByFileExtension(_extension), size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        onPressed: disabled
            ? null
            : () {
                if (offlineContext != null && _offlineCachedPath != null) {
                  OpenFile.open(_offlineCachedPath!);
                } else {
                  launchFile(context, widget.file, _checkLocalStatus);
                }
              },
      ),
    );
  }
}
