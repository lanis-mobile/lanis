import 'package:flutter/material.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/applets/lessons/teacher/widgets/course_folder_card.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:lanis/widgets/marquee.dart';

import '../../../core/sph/sph.dart';
import '../../../models/lessons_teacher.dart';
import 'course_detail_view/course_detail_view.dart';

class LessonsTeacherView extends StatefulWidget {
  final Function? openDrawerCb;
  const LessonsTeacherView({super.key, this.openDrawerCb});

  @override
  State<LessonsTeacherView> createState() => _LessonsTeacherViewState();
}

class _LessonsTeacherViewState extends State<LessonsTeacherView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.openDrawerCb != null
          ? AppBar(
              title: Text(lessonsDefinition.label(context)),
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              ),
              bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(20),
                  child: Container(
                    color: Colors.redAccent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8,
                      children: [
                        SizedBox(width: 8),
                        const Icon(Icons.warning),
                        Expanded(
                          child: MarqueeWidget(
                            child: Text(
                              'Vorschau-Version für Lehrer! Zur Zeit nur teilweise funktionsfähig.',
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                      ],
                    ),
                  )),
            )
          : null,
      body: CombinedAppletBuilder<LessonsTeacherHome>(
        parser: sph!.parser.lessonsTeacherParser,
        phpUrl: lessonsDefinition.appletPhpUrl,
        settingsDefaults: lessonsDefinition.settingsDefaults,
        accountType: sph!.session.accountType,
        builder: (context, data, _, settings, updateSettings, refresh) {
          return RefreshIndicator(
            onRefresh: refresh!,
            child: ListView.builder(
              itemCount: data.courseFolders.length,
              itemBuilder: (context, index) => CourseFolderCard(
                courseFolder: data.courseFolders[index],
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TeacherCourseDetailView(
                        courseFolder: data.courseFolders[index],
                      ),
                    ),
                  );
                  refresh();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
