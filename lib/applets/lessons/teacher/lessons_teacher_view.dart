import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/applets/lessons/teacher/widgets/course_folder_card.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/root_nav.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:lanis/widgets/marquee.dart';
import 'package:liblanis/liblanis.dart';

import 'course_detail_view/course_detail_view.dart';

class LessonsTeacherView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  const LessonsTeacherView({super.key, this.openDrawerCb});

  @override
  ConsumerState<LessonsTeacherView> createState() => _LessonsTeacherViewState();
}

class _LessonsTeacherViewState extends ConsumerState<LessonsTeacherView> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(lessonsDefinition.label(context)),
          leading: widget.openDrawerCb != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => widget.openDrawerCb!(),
                )
              : null,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(lessonsDefinition.label(context)),
        leading: widget.openDrawerCb != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              )
            : null,
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
                      AppLocalizations.of(context).teacherPreviewBanner,
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: CombinedAppletBuilder<LessonsTeacherHome>(
        parser: ref.watch(lessonsTeacherParserProvider),
        phpUrl: lessonsDefinition.appletPhpUrl,
        settingsDefaults: lessonsDefinition.settingsDefaults,
        accountType: session.accountTypeOrNull ??
            ref.read(activeAccountProvider)?.accountType ??
            AccountType.student,
        builder: (context, data, _, settings, updateSettings, refresh) {
          return RefreshIndicator(
            onRefresh: refresh!,
            child: ListView.builder(
              itemCount: data.courseFolders.length,
              itemBuilder: (context, index) => CourseFolderCard(
                courseFolder: data.courseFolders[index],
                onTap: () async {
                  await pushRoot(
                    context,
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
