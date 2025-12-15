import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:intl/intl.dart';
import 'package:lanis/models/study_groups.dart';

import '../../../utils/focused_menu.dart';

class StudentExamsView extends StatelessWidget {
  final List<StudentStudyGroupExam> exams;

  const StudentExamsView({super.key, required this.exams});

  @override
  Widget build(BuildContext context) {
    DateTime today = DateTime.now();
    bool todayMarkerShown = false;
    return ListView.separated(
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        bool showMarker = !todayMarkerShown && exam.date.isAfter(today);
        int difference = (exam.date.differenceInHours(today) / 24).ceil();
        if (showMarker) todayMarkerShown = true;
        return Column(
          children: [
            if (showMarker && difference != 0)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  spacing: 8,
                  children: [
                    Text(DateFormat('dd.MM.yy').format(today)),
                    Expanded(child: Divider()),
                    // Show days until next exam
                    Text(AppLocalizations.of(context)
                        .daysUntilNextExam(difference)),
                  ],
                ),
              ),
            FocusedMenu(
              items: [
                FocusedMenuItem(
                  title: difference.isNegative
                      ? AppLocalizations.of(context)
                          .daysSinceExam(difference.abs())
                      : AppLocalizations.of(context).daysUntilExam(difference),
                  icon: difference.isNegative || difference == 0
                      ? Icons.hourglass_bottom_rounded
                      : Icons.hourglass_top_rounded,
                )
              ],
              margin: EdgeInsets.symmetric(horizontal: 8.0),
              child: Card(
                color: difference == 0
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : null,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(exams[index].courseName,
                              style: Theme.of(context).textTheme.labelLarge),
                          Row(
                            spacing: 4,
                            children: [
                              Text(DateFormat('dd.MM.yy').format(exam.date),
                                  style:
                                      Theme.of(context).textTheme.labelLarge),
                              Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(exam.type),
                          Spacer(),
                          if (exam.hoursOfDay != null &&
                              exam.durationLabel != "") ...[
                            Text(
                                '${exam.hoursOfDay} ${exam.durationLabel != '' ? '(${exam.durationLabel})' : ""}'),
                            Icon(Icons.access_time, size: 16),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      separatorBuilder: (BuildContext context, int index) {
        return SizedBox(height: 8.0);
      },
    );
  }
}
