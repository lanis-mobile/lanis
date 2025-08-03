import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/sph/sph.dart';
import '../../../../models/lessons_teacher.dart';

class CourseCreateNewEntry extends StatefulWidget {
  final CourseFolderDetails courseFolderDetails;
  const CourseCreateNewEntry({super.key, required this.courseFolderDetails});

  @override
  State<CourseCreateNewEntry> createState() => _CourseCreateNewEntryState();
}

class _CourseCreateNewEntryState extends State<CourseCreateNewEntry> {
  CourseFolderNewEntryConstraints get constraints =>
      widget.courseFolderDetails.newEntryConstraints;

  List<String> get availableSchoolEndHours => constraints.schoolHours
      .sublist(constraints.schoolHours.indexOf(_selectedStartHour));

  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  late String _selectedStartHour;
  late String _selectedEndHour;
  final TextEditingController _entryTopicController = TextEditingController();
  final TextEditingController _entryContentController = TextEditingController();
  final TextEditingController _entryHomeworkController =
      TextEditingController();
  bool _useDocumentSubmission = false;
  DateTime _selectedDocumentSubmissionDeadline =
      DateTime.now().add(Duration(days: 7));
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
    return visible ? 'Sichtbar für Schüler' : 'Nicht sichtbar für Schüler';
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
            Text('Eintrag wird gespeichert...'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Neuer Eintrag (${widget.courseFolderDetails.courseName})'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: ListView(
          children: [
            ListTile(
              leading: Icon(Icons.edit_calendar),
              title: Text('Datum'),
              trailing: Row(
                spacing: 8.0,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_prevouslyVisibleForStudents
                        ? Icons.visibility
                        : Icons.visibility_off),
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
                          color: Theme.of(context).colorScheme.secondary),
                    ),
                    child: Text(
                      DateFormat.yMEd(
                              Localizations.localeOf(context).toString())
                          .format(_selectedDate),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                        'Von',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
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
                                child: Text('Stunde $e'),
                              ),
                            )
                            .toList(),
                        value: _selectedStartHour,
                        isExpanded: true,
                        onChanged: (val) {
                          int startHourIndex =
                              constraints.schoolHours.indexOf(val!);
                          int endHourIndex =
                              constraints.schoolHours.indexOf(_selectedEndHour);
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
                        'Bis',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
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
                                child: Text('Stunde $e'),
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
                )),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextFormField(
                controller: _entryTopicController,
                decoration: InputDecoration(
                  labelText: 'Thema *',
                  hintText: vis(constraints.topicVisibleForStudents),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte ein Thema eingeben';
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
                  labelText: 'Inhalt',
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
                  labelText: 'Hausaufgaben',
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
              title: Text('Dokumentenabgabe verwenden'),
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
                        Text('Dokumentenabgabe'),
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
                                  lastDate:
                                      DateTime.now().add(Duration(days: 365)),
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
                                    vertical: 4, horizontal: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary),
                                ),
                                child: Text(
                                  DateFormat.yMEd(
                                          Localizations.localeOf(context)
                                              .toString())
                                      .format(
                                          _selectedDocumentSubmissionDeadline),
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
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
                                    vertical: 4, horizontal: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                ),
                                child: Text(
                                  _selectedDocumentSubmissionTime
                                      .format(context),
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          title: Text('Sichtbar für alle Lernenden'),
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
                label: Text('Speichern'),
                icon: Icon(Icons.save),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    showLoadingDialog();
                    final result =
                        await sph!.parser.lessonsTeacherParser.postNewEntry(
                      book: widget.courseFolderDetails.courseId,
                      datum: DateFormat('dd.MM.yyyy').format(_selectedDate),
                      zeigeauchvorheran: _prevouslyVisibleForStudents,
                      stundenVon: _selectedStartHour,
                      stundenBis: _selectedEndHour,
                      subject: _entryTopicController.text,
                      inhalt: _entryContentController.text,
                      homework: _entryHomeworkController.text,
                      abgabe: _useDocumentSubmission,
                      abgabeBisDate: _selectedDocumentSubmissionDeadline,
                      abgabeBisTime: _selectedDocumentSubmissionTime,
                      abgabeSichtbar: _everySubmissionVisibleForStudents,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop(); // Close loading dialog
                      Navigator.of(context)
                          .pop(result); // Close this screen and return result
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
