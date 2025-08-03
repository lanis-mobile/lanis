import 'package:flutter/material.dart';

import '../../../../core/sph/sph.dart';
import '../../../../models/lessons_teacher.dart';
import '../widgets/course_folder_history_entry_card.dart';

import 'package:lanis/generated/l10n.dart';

import 'course_create_new_entry.dart';

class TeacherCourseDetailView extends StatefulWidget {
  final CourseFolderStartPage courseFolder;
  const TeacherCourseDetailView({super.key, required this.courseFolder});

  @override
  State<TeacherCourseDetailView> createState() =>
      _TeacherCourseDetailViewState();
}

class _TeacherCourseDetailViewState extends State<TeacherCourseDetailView> {
  bool _loading = true;
  late CourseFolderDetails data;

  Future<void> loadData() async {
    setState(() {
      _loading = true;
    });
    data = await sph!.parser.lessonsTeacherParser
        .getCourseFolderDetails(widget.courseFolder.id);
    setState(() {
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseFolder.name),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : data.history.isNotEmpty
              ? RefreshIndicator(
                  onRefresh: loadData,
                  child: ListView.builder(
                    itemCount: data.history.length,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(
                          left: 4,
                          right: 4,
                          bottom: index == data.history.length - 1 ? 80 : 0),
                      child: CourseFolderHistoryEntryCard(
                        entry: data.history[index],
                        courseId: widget.courseFolder.id,
                        afterDeleted: () async {
                          await loadData();
                        },
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadData,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        SizedBox(
                          height: 64,
                        ),
                        Icon(
                          Icons.info,
                          size: 48,
                        ),
                        Text(
                          AppLocalizations.of(context).noEntries,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              label: Text('Neuer Eintrag'),
              icon: Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool?>(
                    MaterialPageRoute(
                        builder: (context) =>
                            CourseCreateNewEntry(courseFolderDetails: data)));
                if (context.mounted) {
                  if (result == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Eintrag erstellt')));
                    await loadData();
                  } else if (result == false) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Eintrag konnte nicht erstellt werden'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
            ),
    );
  }
}
