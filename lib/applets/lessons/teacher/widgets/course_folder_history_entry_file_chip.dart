import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/sph/sph.dart';
import '../../../../models/lessons_teacher.dart';
import '../../../../utils/file_icons.dart';
import '../../../../utils/file_operations.dart';
import '../../../../utils/logger.dart';

class CourseFolderHistoryEntryFileChip extends StatefulWidget {
  final CourseFolderHistoryEntryFile file;
  final String courseId;
  final void Function(bool visibility) onVisibilityChanged;
  final void Function() onFileDeleted;
  const CourseFolderHistoryEntryFileChip(
      {super.key,
      required this.file,
      required this.courseId,
      required this.onVisibilityChanged,
      required this.onFileDeleted});

  @override
  State<CourseFolderHistoryEntryFileChip> createState() =>
      _CourseFolderHistoryEntryFileChipState();
}

class _CourseFolderHistoryEntryFileChipState
    extends State<CourseFolderHistoryEntryFileChip> {
  void changeRemoteVisibility() async {
    final body = {
      "a": 'uploadFileBookHide',
      "id": widget.courseId,
      "e": widget.file.entryId,
      "file": Uri.encodeComponent(widget.file.name),
      "v": widget.file.isVisibleForStudents ? '0' : '1',
    };
    logger.i(body);
    final response = await sph!.session.dio.post(
      'https://start.schulportal.hessen.de/meinunterricht.php',
      queryParameters: body,
      data: body,
      options: Options(
          contentType: "application/x-www-form-urlencoded; charset=UTF-8",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "X-Requested-With": "XMLHttpRequest",
          }),
    );
    final String responseString = response.data.toString();
    if (responseString == '"1"') {
      widget.onVisibilityChanged(!widget.file.isVisibleForStudents);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sichtbarkeit erfolgreich geändert'),
          backgroundColor: Colors.green,
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Fehler beim Ändern der Sichtbarkeit'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void deleteRemoteFile() async {
    final bool? confirmPositive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning, color: Colors.red),
        title: Text('Wirklich löschen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text('Möchtest du die Datei wirklich löschen?'),
            Text(
              widget.file.name,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.visible,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Löschen'),
          ),
        ],
      ),
    );
    if (!confirmPositive!) return;

    final data = {
      "a": 'deleteFileBook',
      "id": widget.courseId,
      "e": widget.file.entryId,
      "file": Uri.encodeComponent(widget.file.name),
    };
    final response = await sph!.session.dio.post(
      'https://start.schulportal.hessen.de/meinunterricht.php',
      queryParameters: data,
      data: data,
      options: Options(
          contentType: "application/x-www-form-urlencoded; charset=UTF-8",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "X-Requested-With": "XMLHttpRequest",
          }),
    );
    final String responseString = response.data.toString();
    if (responseString == '"1"') {
      widget.onFileDeleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Datei erfolgreich gelöscht'),
          backgroundColor: Colors.green,
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Fehler beim Löschen der Datei'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4.0,
        children: [
          Icon(
            getIconByFileExtension(widget.file.extension),
            size: 16,
            color: Theme.of(context).colorScheme.onSecondary,
          ),
          Text(
            widget.file.name,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            overflow: TextOverflow.fade,
          ),
          Icon(
            widget.file.isVisibleForStudents
                ? Icons.visibility
                : Icons.visibility_off,
            size: 16,
            color: widget.file.isVisibleForStudents
                ? Colors.green[800]
                : Theme.of(context).colorScheme.onSecondary,
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.secondary,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSecondary,
          ),
      onPressed: () async {
        final RenderBox button = context.findRenderObject() as RenderBox;
        final RenderBox overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final RelativeRect position = RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(Offset.zero, ancestor: overlay),
            button.localToGlobal(button.size.bottomRight(Offset.zero),
                ancestor: overlay),
          ),
          Offset.zero & overlay.size,
        );

        final result = await showMenu(
          context: context,
          position: position,
          items: [
            PopupMenuItem<String>(
              value: 'open',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new, size: 16),
                  SizedBox(width: 4),
                  Text('Öffnen oder Teilen'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'visibility',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      widget.file.isVisibleForStudents
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 16),
                  SizedBox(width: 4),
                  Text('Sichtbarkeit (SuS) ändern'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: 16),
                  SizedBox(width: 4),
                  Text('Löschen'),
                ],
              ),
            ),
          ],
        );
        if (result != null) {
          switch (result) {
            case 'open':
              if (context.mounted)
                showFileModal(context,
                    FileInfo(name: widget.file.name, url: widget.file.url));
              break;
            case 'visibility':
              changeRemoteVisibility();
              break;
            case 'delete':
              deleteRemoteFile();
              break;
          }
        }
      },
    );
  }
}
