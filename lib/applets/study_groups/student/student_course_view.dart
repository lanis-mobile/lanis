import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lanis/core/sph/sph.dart';
import 'package:lanis/models/study_groups.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentCourseView extends StatelessWidget {
  final List<StudentStudyGroups> studyData;

  const StudentCourseView({super.key, required this.studyData});

  BorderRadius getRadius(final int index, final int length) {
    if (length == 1) {
      return BorderRadius.circular(12.0);
    }

    if (index == 0) {
      return BorderRadius.vertical(top: Radius.circular(12.0));
    } else if (index == 1 && length == 2) {
      return BorderRadius.vertical(bottom: Radius.circular(12.0));
    } else {
      if (index == length - 1) {
        return BorderRadius.vertical(bottom: Radius.circular(12.0));
      }

      return BorderRadius.zero;
    }
  }

  Future<File> getImage(
      BuildContext context, ({String name, String url}) picture) async {
    String path = await sph!.storage.downloadFile(picture.url, picture.name);
    return File(path);
  }

  @override
  Widget build(BuildContext context) {
    Map<int, String> years = {};

    for (int i = 0; i < studyData.length; i++) {
      if (!years.containsValue(studyData[i].halfYear)) {
        years[i] = studyData[i].halfYear;
      }
    }

    return ListView.builder(
      itemCount: studyData.length,
      itemBuilder: (context, index) {
        final exams = studyData[index].exams;

        return Column(
          children: [
            if (years.containsKey(index))
              Padding(
                padding: const EdgeInsets.only(
                  left: 8.0,
                  right: 8.0,
                  top: 16.0,
                  bottom: 8.0,
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Text(
                      studyData[index].halfYear,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Expanded(
                      child: Divider(),
                    )
                  ],
                ),
              )
            else
              SizedBox(
                height: 8.0,
              ),
            Card(
              margin: EdgeInsets.symmetric(horizontal: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 2.0,
                  children: [
                    if (studyData[index].picture != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FutureBuilder(
                            future:
                                getImage(context, studyData[index].picture!),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                      ConnectionState.done ||
                                  snapshot.data == null ||
                                  snapshot.hasError) {
                                return CircleAvatar(
                                  radius: 25.0,
                                  child: Icon(Icons.person),
                                );
                              }

                              return CircleAvatar(
                                radius: 25.0,
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(100.0),
                                    child: Image.file(snapshot.data!)),
                              );
                            },
                          ),
                          if (studyData[index].email != null)
                            IconButton.filledTonal(
                              onPressed: () {
                                launchUrl(studyData[index].email!);
                              },
                              icon: Icon(Icons.email_rounded),
                            ),
                        ],
                      ),
                      SizedBox(
                        height: 8.0,
                      )
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(studyData[index].courseName,
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "${studyData[index].teacher} (${studyData[index].teacherKuerzel})",
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium!
                              .copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (exams != null && exams.isNotEmpty)
                      SizedBox(
                        height: 8.0,
                      ),
                    if (exams != null)
                      for (int i = 0; i < exams.length; i++)
                        Card.filled(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: getRadius(i, exams.length),
                          ),
                          child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(exams[i].type),
                                  exams[i].duration.isEmpty
                                      ? Text(exams[i].time)
                                      : Text(
                                          '${exams[i].time} (${exams[i].duration})'),
                                  Text(DateFormat('dd.MM.yy')
                                      .format(exams[i].date)),
                                ],
                              )),
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
