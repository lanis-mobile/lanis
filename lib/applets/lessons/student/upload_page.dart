import 'dart:async';

import 'package:dart_date/dart_date.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/file_picker.dart';
import 'package:lanis/widgets/error_view.dart';

import '../../../core/sph/sph.dart';
import '../../../models/lessons.dart';
import '../../../models/client_status_exceptions.dart';
import '../../../utils/file_operations.dart';
import '../../../utils/logger.dart';

class UploadScreen extends StatefulWidget {
  final String url;
  final String name;
  final String status;
  const UploadScreen(
      {super.key, required this.url, required this.name, required this.status});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late Future _future;
  final ValueNotifier<int> _addedFiles =
      ValueNotifier(0); // Could also use a stream

  final List<MultipartFile> _multipartFiles = [];
  final List<ListTile> _fileWidgets = [];

  void forceReloadPage() {
    setState(() {
      _future = sph!.parser.lessonsStudentParser.getUploadInfo(widget.url);
    });
  }

  @override
  void initState() {
    _future = sph!.parser.lessonsStudentParser.getUploadInfo(widget.url);
    super.initState();
  }

  @override
  void dispose() {
    _addedFiles.dispose();
    super.dispose();
  }

  void showSnackbar({required String text, SnackBarAction? action}) {
    if (mounted) {
      // Hide the current SnackBar if one is already visible.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(text),
            duration: const Duration(seconds: 6),
            action: action),
      );
    }
  }

  static const Divider indentedDivider = Divider(
    indent: 16,
    endIndent: 16,
  );

  Container uploadStatusContainer(String text) => Container(
        padding: const EdgeInsets.all(12.0),
        margin:
            const EdgeInsets.only(left: 16, right: 16, top: 4.0, bottom: 4.0),
        decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );

  Container requirementsInfo(List<Widget> widgets, {Color? color}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4.0),
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        decoration: BoxDecoration(
            color: color ??
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [...widgets],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError && snapshot.error is LanisException) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(widget.name),
                ),
                body: ErrorView(
                  error: snapshot.error as LanisException,
                ),
              );
            }

            final DateTime startDate = DateFormat("EEEE d.M.yy H:mm", "de")
                .parse(snapshot.data["start"]
                    .replaceAll(",", "")
                    .replaceAll(" den", "")
                    .replaceAll(" Uhr", ""));
            final DateTime endDate = DateFormat("EEEE d.M.yy H:mm", "de").parse(
                snapshot.data["deadline"]
                    .replaceAll(",", "")
                    .replaceAll(" den", "")
                    .replaceAll(" Uhr", ""));
            final DateTime now = DateTime.now();

            final DateTime deleteDate = DateFormat("d.M.yyyy", "de")
                .parse(snapshot.data["automatic_deletion"]);
            final bool filesDeleted =
                now.isAfter(deleteDate) || now.isAtSameMomentAs(deleteDate);

            final bool isBeforeStart = now.isBefore(startDate);

            return Scaffold(
              appBar: AppBar(
                title: Text(widget.name),
              ),
              floatingActionButton: ValueListenableBuilder(
                  valueListenable: _addedFiles,
                  builder: (_, filesLength, __) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (filesLength != 0) ...[
                          Column(
                            children: [
                              FloatingActionButton(
                                heroTag: null,
                                onPressed: () async {
                                  if (snapshot.data["upload_multiple_files"] ==
                                          false ||
                                      snapshot.data[
                                              "upload_any_number_of_times"] ==
                                          false) {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: Text(AppLocalizations()
                                              .uploadNotPossible),
                                          content: Text(AppLocalizations()
                                              .multipleOrUnlimitedSubmissionNotSupportedMsg),
                                          actions: [
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child:
                                                  Text(AppLocalizations().back),
                                            )
                                          ],
                                        );
                                      },
                                    );
                                    return;
                                  }

                                  showSnackbar(
                                      text: AppLocalizations()
                                          .tryingToUploadFiles);

                                  List<FileStatus> fileStatus;

                                  try {
                                    fileStatus = await sph!
                                        .parser.lessonsStudentParser
                                        .uploadFile(
                                      course: snapshot.data["course_id"],
                                      entry: snapshot.data["entry_id"],
                                      upload: snapshot.data["upload_id"],
                                      file1: _multipartFiles[0],
                                      file2: _multipartFiles.elementAtOrNull(1),
                                      file3: _multipartFiles.elementAtOrNull(2),
                                      file4: _multipartFiles.elementAtOrNull(3),
                                      file5: _multipartFiles.elementAtOrNull(4),
                                    );
                                  } on LanisException catch (ex) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();
                                      Navigator.of(context).push(
                                          MaterialPageRoute(builder: (context) {
                                        return Scaffold(
                                          appBar: AppBar(),
                                          body: ErrorView(
                                            error: ex,
                                          ),
                                        );
                                      }));
                                    } else {
                                      rethrow;
                                    }
                                    return;
                                  }

                                  int successfulUploads = 0;
                                  bool renamed = false;
                                  for (final status in fileStatus) {
                                    if (status.status == "erfolgreich") {
                                      successfulUploads++;
                                      if (status.message!.contains(
                                          "Datei mit gleichem Namen schon vorhanden.")) {
                                        renamed = true;
                                      }
                                    }
                                  }

                                  showSnackbar(
                                      text:
                                          "$successfulUploads/${fileStatus.length} ${AppLocalizations().xWasUploadedSuccessfully} ${renamed == true ? AppLocalizations().howeverSomeFilesWereRenamed : ''}",
                                      action: SnackBarAction(
                                          label: AppLocalizations().seeMore,
                                          onPressed: () {
                                            // We render the Widgets before so we can have a dynamically sized AlertDialog.
                                            final List<ListTile>
                                                fileStatusWidgets = [];

                                            for (final status in fileStatus) {
                                              fileStatusWidgets.add(ListTile(
                                                leading: status.status ==
                                                        "erfolgreich"
                                                    ? const Icon(Icons.done)
                                                    : const Icon(Icons.error),
                                                title: Text(status.name),
                                                subtitle:
                                                    status.message != null &&
                                                            status.message != ""
                                                        ? Text(status.message!)
                                                        : null,
                                              ));
                                            }

                                            showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return AlertDialog(
                                                    title: Text(
                                                        AppLocalizations()
                                                            .moreDetails),
                                                    content: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        ...fileStatusWidgets
                                                      ],
                                                    ),
                                                    actions: [
                                                      FilledButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(),
                                                          child: Text(
                                                              AppLocalizations()
                                                                  .back))
                                                    ],
                                                  );
                                                });
                                          }));

                                  _addedFiles.value = 0;
                                  _multipartFiles.clear();
                                  _fileWidgets.clear();

                                  forceReloadPage();
                                },
                                child: const Icon(Icons.upload),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                            ],
                          ),
                        ],
                        if (filesLength < 5 &&
                            snapshot.data["course_id"] != null) ...[
                          FloatingActionButton.extended(
                            heroTag: null,
                            label: Text(
                              "$filesLength / 5",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              final List<PickedFile> pickedFiles =
                                  await pickMultipleFiles(context,
                                      snapshot.data["allowed_file_types"]);

                              if (pickedFiles.isEmpty) {
                                return;
                              }

                              if ((pickedFiles.length + filesLength) > 5) {
                                showSnackbar(
                                    text: AppLocalizations().maxOfFiveFiles);
                                return;
                              }

                              num maxFileSize = num.parse(snapshot
                                      .data["max_file_size"]
                                      .replaceAll("MB", "")
                                      .replaceAll(",", ".")) *
                                  1000000;

                              for (final file in pickedFiles) {
                                if (!snapshot.data["allowed_file_types"]
                                    .contains(file.extension.toUpperCase())) {
                                  showSnackbar(
                                      text:
                                          "${AppLocalizations().fileTypeNotAllowed} (${file.name})");
                                  continue;
                                }

                                if ((file.size ?? 0) > maxFileSize) {
                                  showSnackbar(
                                      text:
                                          "${AppLocalizations().maxFileSizeExceeded} (${file.name})");
                                  continue;
                                }

                                // Only check for filename like Lanis.
                                for (final element in _multipartFiles) {
                                  if (element.filename == file.name) {
                                    showSnackbar(
                                        text:
                                            "${AppLocalizations().fileNameAlreadyExists} (${file.name})");
                                    continue;
                                  }
                                }

                                final String? mimeType = file.mimeType;
                                if (mimeType == null) {
                                  showSnackbar(
                                      text:
                                          "${AppLocalizations().failedToDetectFileType} (${file.name})");
                                  continue;
                                }

                                final MultipartFile multipartFile =
                                    await file.intoMultipart();

                                _multipartFiles.add(multipartFile);
                                _fileWidgets.add(ListTile(
                                  title: Text(file.name),
                                  trailing: const Icon(Icons.remove),
                                  onTap: () {
                                    // We need to calculate the index dynamically because you can remove every tile at any index.
                                    // Maybe there is a better way.
                                    int tileIndex = _fileWidgets
                                        .indexWhere((ListTile element) {
                                      final Text textWidget =
                                          element.title as Text;
                                      final String text = textWidget.data!;

                                      return text == file.name;
                                    });
                                    _fileWidgets.removeAt(tileIndex);
                                    _multipartFiles.removeAt(tileIndex);
                                    _addedFiles.value -= 1;
                                  },
                                ));
                                _addedFiles.value += 1;
                              }
                            },
                          ),
                        ]
                      ],
                    );
                  }),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    requirementsInfo([
                      ListTile(
                        title: Text(
                          AppLocalizations().start,
                        ),
                        subtitle: Text(AppLocalizations().dateTimeString(
                            startDate.format("EEEE"),
                            startDate.format("dd.MM.yyyy"),
                            startDate.format("hh:mm"))),
                        leading: const Icon(Icons.hourglass_top),
                      ),
                      ListTile(
                        title: Text(
                          AppLocalizations().end,
                        ),
                        subtitle: Text(AppLocalizations().dateTimeString(
                            endDate.format("EEEE"),
                            endDate.format("dd.MM.yyyy"),
                            endDate.format("hh:mm"))),
                        leading: const Icon(Icons.hourglass_bottom),
                      ),
                    ]),
                    Visibility(
                      visible:
                          isBeforeStart || snapshot.data["course_id"] != null,
                      child: requirementsInfo([
                        ListTile(
                          title: Text(
                            AppLocalizations().uploadOfMultipleFiles,
                          ),
                          subtitle: Text(
                            snapshot.data["upload_multiple_files"]
                                ? AppLocalizations().possible
                                : AppLocalizations().notPossible,
                          ),
                          leading: snapshot.data["upload_multiple_files"]
                              ? const Icon(Icons.file_upload)
                              : const Icon(Icons.file_upload_off),
                        ),
                        ListTile(
                          title: Text(AppLocalizations().uploadUnlimitedTimes),
                          subtitle: Text(
                              snapshot.data["upload_any_number_of_times"]
                                  ? AppLocalizations().possible
                                  : AppLocalizations().notPossible),
                          leading: snapshot.data["upload_any_number_of_times"]
                              ? const Icon(Icons.file_upload)
                              : const Icon(Icons.file_upload_off),
                        ),
                      ]),
                    ),
                    Visibility(
                      visible:
                          isBeforeStart || snapshot.data["course_id"] != null,
                      child: requirementsInfo([
                        ListTile(
                          title: Text(
                            "${AppLocalizations().filesVisibleForX}${snapshot.data["visibility"]}",
                          ),
                          leading: const Icon(Icons.visibility),
                        ),
                        ListTile(
                          title: Text(
                            AppLocalizations().automaticDeletion,
                          ),
                          subtitle: Text(snapshot.data["automatic_deletion"]),
                          leading: const Icon(Icons.delete_forever),
                        ),
                      ]),
                    ),
                    Visibility(
                      visible:
                          !isBeforeStart && snapshot.data["course_id"] == null,
                      child: requirementsInfo(
                        [
                          ListTile(
                            title: filesDeleted
                                ? Text(AppLocalizations().filesWereDeleted)
                                : Text(AppLocalizations().automaticDeletion),
                            subtitle: filesDeleted
                                ? null
                                : Text(snapshot.data["automatic_deletion"]),
                            leading: const Icon(Icons.delete_forever),
                          ),
                        ],
                        color: filesDeleted ? Colors.redAccent : null,
                      ),
                    ),
                    Visibility(
                      visible:
                          isBeforeStart || snapshot.data["course_id"] != null,
                      child: requirementsInfo([
                        ListTile(
                          title: Text(
                            AppLocalizations().allowedFileTypes,
                          ),
                          subtitle: Text(snapshot.data["allowed_file_types"]
                              .toString()
                              .substring(
                                  1,
                                  snapshot.data["allowed_file_types"]
                                          .toString()
                                          .length -
                                      1)),
                          leading: const Icon(Icons.description),
                        ),
                        ListTile(
                          title: Text(AppLocalizations().maxFileSize),
                          subtitle: Text(snapshot.data["max_file_size"]),
                          leading: const Icon(Icons.description),
                        ),
                      ]),
                    ),
                    Visibility(
                      visible: snapshot.data["additional_text"] != null,
                      child: requirementsInfo([
                        if (snapshot.data["additional_text"] != null) ...[
                          ListTile(
                            title: Text(AppLocalizations().moreInformation),
                            subtitle:
                                Text(snapshot.data["additional_text"] ?? ""),
                            leading: const Icon(Icons.info),
                          ),
                        ]
                      ]),
                    ),
                    if (snapshot.data["public_files"].length != 0) ...[
                      indentedDivider
                    ],
                    ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: snapshot.data["public_files"].length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              snapshot.data["public_files"][index].name,
                              style: !filesDeleted
                                  ? Theme.of(context).textTheme.titleMedium
                                  : Theme.of(context).textTheme.bodyLarge,
                            ),
                            subtitle: Text(
                              snapshot.data["public_files"][index].person,
                              style: !filesDeleted
                                  ? Theme.of(context).textTheme.bodyMedium
                                  : null,
                            ),
                            onTap: !filesDeleted
                                ? () async {
                                    showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: Text(
                                                AppLocalizations().downloading),
                                            content: Center(
                                              heightFactor: 1.1,
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        });
                                    sph!.storage
                                        .downloadFile(
                                            snapshot.data["public_files"][index]
                                                .url,
                                            snapshot.data["public_files"][index]
                                                .name)
                                        .then((filepath) {
                                      if (context.mounted) {
                                        Navigator.of(context).pop();

                                        if (filepath == "") {
                                          showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                    title: Text(
                                                        "${AppLocalizations().error}!"),
                                                    content: Text(AppLocalizations()
                                                        .failedToDownloadFileMsg(
                                                            snapshot
                                                                .data[
                                                                    "public_files"]
                                                                    [index]
                                                                .name)),
                                                    actions: [
                                                      TextButton(
                                                        child: Text(
                                                            AppLocalizations()
                                                                .ok),
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                      ),
                                                    ],
                                                  ));
                                        }
                                      } else {
                                        OpenFile.open(filepath);
                                      }
                                    });
                                  }
                                : null,
                          );
                        }),
                    indentedDivider,
                    if (snapshot.data["own_files"].length == 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        margin: const EdgeInsets.only(
                            left: 16, right: 16, top: 4.0, bottom: 4.0),
                        decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          AppLocalizations().noSubmissionMsg,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    ],
                    ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: snapshot.data["own_files"].length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              snapshot.data["own_files"][index].name,
                              style: !filesDeleted
                                  ? Theme.of(context).textTheme.titleMedium
                                  : Theme.of(context).textTheme.bodyLarge,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  snapshot.data["own_files"][index].time,
                                  style: !filesDeleted
                                      ? Theme.of(context).textTheme.bodyMedium
                                      : null,
                                ),
                                if (snapshot.data["own_files"][index].comment !=
                                    null)
                                  Text(
                                      snapshot.data["own_files"][index].comment)
                              ],
                            ),
                            trailing: !filesDeleted
                                ? IconButton(
                                    onPressed: () async {
                                      final TextEditingController
                                          passwordController =
                                          TextEditingController();
                                      showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: Text(AppLocalizations()
                                                  .confirmWithPassword),
                                              content: TextField(
                                                obscureText: true,
                                                enableSuggestions: false,
                                                autocorrect: false,
                                                controller: passwordController,
                                              ),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: Text(
                                                        AppLocalizations()
                                                            .back)),
                                                FilledButton(
                                                  onPressed: () async {
                                                    Navigator.pop(context);

                                                    showSnackbar(
                                                        text: AppLocalizations()
                                                            .tryingToDeleteFiles);
                                                    String response;
                                                    try {
                                                      response = await sph!
                                                          .parser
                                                          .lessonsStudentParser
                                                          .deleteUploadedFile(
                                                        course: snapshot
                                                            .data["course_id"],
                                                        entry: snapshot
                                                            .data["entry_id"],
                                                        upload: snapshot
                                                            .data["upload_id"],
                                                        file: snapshot
                                                            .data["own_files"]
                                                                [index]
                                                            .index,
                                                        userPasswordEncrypted: sph!
                                                            .session.cryptor
                                                            .encryptString(
                                                                passwordController
                                                                    .text),
                                                      );
                                                    } on LanisException catch (ex) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .hideCurrentSnackBar();
                                                        Navigator.of(context).push(
                                                            MaterialPageRoute(
                                                                builder:
                                                                    (context) {
                                                          return Scaffold(
                                                            appBar: AppBar(),
                                                            body: ErrorView(
                                                              error: ex,
                                                            ),
                                                          );
                                                        }));
                                                      } else {
                                                        rethrow;
                                                      }
                                                      return;
                                                    }

                                                    String message =
                                                        AppLocalizations()
                                                            .unknownErrorWhileDeletingFile;

                                                    if (response == "-1") {
                                                      message =
                                                          AppLocalizations()
                                                              .wrongPassword;
                                                    } else if (response ==
                                                        "-2") {
                                                      message = AppLocalizations()
                                                          .failedToDeleteFile;
                                                    } else if (response ==
                                                        "1") {
                                                      message = AppLocalizations()
                                                          .fileDeletedSuccessfully;
                                                    }

                                                    showSnackbar(
                                                        text:
                                                            "$message ($response)");

                                                    forceReloadPage();
                                                  },
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 4.0),
                                                        child:
                                                            Icon(Icons.warning),
                                                      ),
                                                      Text(AppLocalizations()
                                                          .deletePermanently)
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          });
                                    },
                                    icon: const Icon(Icons.delete))
                                : null,
                            onLongPress: !filesDeleted
                                ? () {
                                    showFileModal(
                                        context,
                                        FileInfo(
                                          name: snapshot
                                              .data["own_files"][index].name,
                                          url: Uri.parse(snapshot
                                              .data["own_files"][index].url),
                                        ));
                                  }
                                : null,
                            onTap: !filesDeleted
                                ? () {
                                    logger.d(snapshot.data["own_files"][index]);
                                    launchFile(
                                        context,
                                        FileInfo(
                                          name: snapshot
                                              .data["own_files"][index].name,
                                          url: Uri.parse(snapshot
                                              .data["own_files"][index].url),
                                        ),
                                        () {});
                                  }
                                : null,
                          );
                        }),
                    indentedDivider,
                    ValueListenableBuilder(
                        valueListenable: _addedFiles,
                        builder: (context, value, _) {
                          if (value == 0 &&
                              snapshot.data["course_id"] == null) {
                            if (now.isBefore(startDate)) {
                              String? waitingTime;

                              final Duration difference =
                                  now.difference(startDate);

                              if (difference.inHours >= 24) {
                                final days = difference.inDays;
                                if (days == 1) {
                                  waitingTime =
                                      "$days ${AppLocalizations().day}";
                                } else {
                                  waitingTime =
                                      "$days ${AppLocalizations().days}";
                                }
                              } else if (difference.inHours <= 1) {
                                final minutes = difference.inMinutes;
                                if (minutes == 1) {
                                  waitingTime =
                                      "$minutes ${AppLocalizations().minute}";
                                } else {
                                  waitingTime =
                                      "$minutes ${AppLocalizations().minutes}";
                                }
                              } else {
                                final hours = difference.inHours;
                                if (hours == 1) {
                                  waitingTime =
                                      "$hours ${AppLocalizations().hour}";
                                } else {
                                  waitingTime =
                                      "$hours ${AppLocalizations().hours}";
                                }
                              }

                              return uploadStatusContainer(AppLocalizations()
                                  .submissionPossibleInX(waitingTime));
                            }

                            return uploadStatusContainer(
                                AppLocalizations().submissionNoLongerPossible);
                          } else if (value == 0) {
                            return uploadStatusContainer(
                                AppLocalizations().addFilesToUpload);
                          } else {
                            return Container(
                                margin: const EdgeInsets.only(
                                    top: 8, bottom: 8, left: 20, right: 20),
                                decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  children: [
                                    ..._fileWidgets,
                                    if (value != 5) ...[]
                                  ],
                                ));
                          }
                        }),
                    SizedBox.fromSize(
                      size: const Size(0, 104),
                    )
                  ],
                ),
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.name),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        });
  }
}
