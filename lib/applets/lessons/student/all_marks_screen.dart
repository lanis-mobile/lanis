import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

import '../../../core/sph/sph.dart';
import '../../../models/lessons.dart';

class AllMarksScreen extends StatefulWidget {
  final Lessons lessons;
  const AllMarksScreen({super.key, required this.lessons});

  @override
  State<AllMarksScreen> createState() => _AllMarksScreenState();
}

class _AllMarksScreenState extends State<AllMarksScreen> {
  final Map<String, List<LessonMark>> _marksByCourseName = {};
  int _loaded = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await Future.wait(
      widget.lessons.map((lesson) async {
        try {
          final detail =
              await sph!.parser.lessonsStudentParser.getDetailedCourseView(
            lesson.courseURL.toString(),
          );
          if (!mounted) return;
          setState(() {
            if (detail.marks.isNotEmpty) {
              _marksByCourseName[detail.name] = detail.marks;
            }
            _loaded++;
          });
        } catch (_) {
          if (!mounted) return;
          setState(() => _loaded++);
        }
      }),
    );
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.lessons.length;
    final courses = _marksByCourseName.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).allMarks),
      ),
      body: Column(
        children: [
          if (!_done)
            LinearProgressIndicator(value: total == 0 ? null : _loaded / total),
          if (!_done)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                AppLocalizations.of(context).allMarksLoading(_loaded, total),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: courses.isEmpty && _done
                ? Center(
                    child: Text(AppLocalizations.of(context).allMarksNoData),
                  )
                : ListView.builder(
                    itemCount: courses.length,
                    itemBuilder: (context, i) {
                      final entry = courses[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ExpansionTile(
                          title: Text(entry.key),
                          subtitle: Text(
                            '${entry.value.length} ${AppLocalizations.of(context).performance}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          children: entry.value
                              .map(
                                (mark) => ListTile(
                                  title: Text(mark.name),
                                  subtitle: Text(mark.date),
                                  trailing: Text(
                                    mark.mark,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
