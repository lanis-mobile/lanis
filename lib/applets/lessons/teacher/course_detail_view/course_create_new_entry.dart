import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:intl/intl.dart';

class CourseCreateNewEntry extends ConsumerStatefulWidget {
  final CourseFolderDetails courseFolderDetails;
  const CourseCreateNewEntry({super.key, required this.courseFolderDetails});

  @override
  ConsumerState<CourseCreateNewEntry> createState() => _CourseCreateNewEntryState();
}

class _CourseCreateNewEntryState extends ConsumerState<CourseCreateNewEntry> {
  CourseFolderNewEntryConstraints get constraints =>
      widget.courseFolderDetails.newEntryConstraints;

  List<String> get availableSchoolEndHours => constraints.schoolHours.sublist(
    constraints.schoolHours.indexOf(_selectedStartHour),
  );

  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  late String _selectedStartHour;
  late String _selectedEndHour;
  final TextEditingController _entryTopicController = TextEditingController();
  final TextEditingController _entryContentController = TextEditingController();
  final TextEditingController _entryHomeworkController =
      TextEditingController();
  bool _useDocumentSubmission = false;
  DateTime _selectedDocumentSubmissionDeadline = DateTime.now().add(
    Duration(days: 7),
  );
  TimeOfDay _selectedDocumentSubmissionTime = TimeOfDay(hour: 22, minute: 00);
  bool _everySubmissionVisibleForStudents = false;
  bool _prevouslyVisibleForStudents = false;

  @override
  void initState() {
    super.initState();
    _selectedStartHour = constraints.schoolHours.first;
    _selectedEndHour = constraints.schoolHours.first;
  }

  String vis(bool visible) {
    final l10n = AppLocalizations.of(context);
    return visible ? l10n.visibleForStudents : l10n.notVisibleForStudents;
  }

  void showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16.0,
          children: [
            CircularProgressIndicator(),
            Text(AppLocalizations.of(context).entrySaving),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.newEntryTitle(widget.courseFolderDetails.courseName),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: ListView(
          children: [
            ListTile(
              leading: Icon(Icons.edit_calendar),
              title: Text(l10n.date),
              trailing: Row(
                spacing: 8.0,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _prevouslyVisibleForStudents
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _prevouslyVisibleForStudents =
                            !_prevouslyVisibleForStudents;
                      });
                    },
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    child: Text(
                      DateFormat.yMEd(
                        Localizations.localeOf(context).toString(),
                      ).format(_selectedDate),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (picked != null && picked != _selectedDate) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 16,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Icon(Icons.access_time),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      l10n.start,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: DropdownButton<String>(
                      items: constraints.schoolHours
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(l10n.lessonHour(e)),
                            ),
                          )
                          .toList(),
                      value: _selectedStartHour,
                      isExpanded: true,
                      onChanged: (val) {
                        int startHourIndex = constraints.schoolHours.indexOf(
                          val!,
                        );
                        int endHourIndex = constraints.schoolHours.indexOf(
                          _selectedEndHour,
                        );
                        setState(() {
                          _selectedStartHour = val;
                          if (startHourIndex > endHourIndex) {
                            _selectedEndHour = val;
                          }
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      l10n.end,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: DropdownButton<String>(
                      items: availableSchoolEndHours
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(l10n.lessonHour(e)),
                            ),
                          )
                          .toList(),
                      value: _selectedEndHour,
                      isExpanded: true,
                      onChanged: (val) {
                        setState(() {
                          _selectedEndHour = val!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextFormField(
                controller: _entryTopicController,
                decoration: InputDecoration(
                  labelText: l10n.topicRequiredLabel,
                  hintText: vis(constraints.topicVisibleForStudents),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.pleaseEnterTopic;
                  }
                  return null;
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextFormField(
                controller: _entryContentController,
                decoration: InputDecoration(
                  labelText: l10n.contentLabel,
                  hintText: vis(constraints.contentVisibleForStudents),
                ),
                maxLines: 5,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextFormField(
                controller: _entryHomeworkController,
                decoration: InputDecoration(
                  labelText: l10n.homework,
                  hintText: vis(constraints.homeworkVisibleForStudents),
                ),
                maxLines: 5,
              ),
            ),
            SwitchListTile(
              value: _useDocumentSubmission,
              onChanged: (val) {
                setState(() {
                  _useDocumentSubmission = val;
                });
              },
              title: Text(l10n.useDocumentSubmission),
            ),
            if (_useDocumentSubmission)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      spacing: 8.0,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.documentSubmission),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _selectedDocumentSubmissionDeadline,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    Duration(days: 365),
                                  ),
                                );
                                if (picked != null &&
                                    picked !=
                                        _selectedDocumentSubmissionDeadline) {
                                  setState(() {
                                    _selectedDocumentSubmissionDeadline =
                                        picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                ),
                                child: Text(
                                  DateFormat.yMEd(
                                    Localizations.localeOf(context).toString(),
                                  ).format(_selectedDocumentSubmissionDeadline),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: _selectedDocumentSubmissionTime,
                                );
                                if (picked != null &&
                                    picked != _selectedDocumentSubmissionTime) {
                                  setState(() {
                                    _selectedDocumentSubmissionTime = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                child: Text(
                                  _selectedDocumentSubmissionTime.format(
                                    context,
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          title: Text(l10n.visibleForAllLearners),
                          value: _everySubmissionVisibleForStudents,
                          onChanged: (val) {
                            setState(() {
                              _everySubmissionVisibleForStudents = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ElevatedButton.icon(
                label: Text(l10n.save),
                icon: Icon(Icons.save),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    showLoadingDialog();
                    try {
                      final result = await ref
                          .read(lessonsTeacherParserProvider)
                          .postNewEntry(
                            book: widget.courseFolderDetails.courseId,
                            datum: DateFormat(
                              'dd.MM.yyyy',
                            ).format(_selectedDate),
                            zeigeauchvorheran: _prevouslyVisibleForStudents,
                            stundenVon: _selectedStartHour,
                            stundenBis: _selectedEndHour,
                            subject: _entryTopicController.text,
                            inhalt: _entryContentController.text,
                            homework: _entryHomeworkController.text,
                            abgabe: _useDocumentSubmission,
                            abgabeBisDate:
                                _selectedDocumentSubmissionDeadline,
                            abgabeBisTime:
                                _selectedDocumentSubmissionTime.toSph(),
                            abgabeSichtbar: _everySubmissionVisibleForStudents,
                          );
                      if (!context.mounted) return;
                      Navigator.of(context).pop(); // Close loading dialog
                      Navigator.of(context).pop(result);
                    } catch (_) {
                      if (!context.mounted) return;
                      Navigator.of(context).pop(); // Close loading dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context).error,
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            SizedBox(height: 150),
          ],
        ),
      ),
    );
  }
}

// ignore: non_constant_identifier_names
String HHmm(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
