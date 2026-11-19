import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

import '../definition.dart';
import '../student/lesson_list_tile.dart';

/// One overview request, with each child's courses and attendance kept separate.
class LessonsParentView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  const LessonsParentView({super.key, this.openDrawerCb});

  @override
  ConsumerState<LessonsParentView> createState() => _LessonsParentViewState();
}

class _LessonsParentViewState extends ConsumerState<LessonsParentView> {
  String? _selectedPupilId;

  @override
  Widget build(BuildContext context) {
    ref.listen(activeAccountIdProvider, (previous, next) {
      if (previous != next) _selectedPupilId = null;
    });
    final header = AppBar(
      title: Text(lessonsDefinition.label(context)),
      leading: widget.openDrawerCb == null
          ? null
          : IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => widget.openDrawerCb!(),
            ),
    );
    final session = ref.watch(sessionProvider).asData?.value;
    final accountId = ref.watch(activeAccountIdProvider);
    if (session == null) {
      return Scaffold(
        appBar: header,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return CombinedAppletBuilder<ParentLessonsOverview>(
      parser: ref.watch(lessonsParentParserProvider),
      phpUrl: lessonsDefinition.appletPhpUrl,
      settingsDefaults: lessonsDefinition.settingsDefaults,
      accountType: AccountType.parent,
      loadingAppBar: header,
      builder: (context, overview, type, settings, updateSetting, refresh) =>
          _ParentLessonsTabs(
            key: ValueKey(accountId),
            overview: overview,
            openDrawerCb: widget.openDrawerCb,
            initialPupilId: _selectedPupilId,
            onPupilSelected: (id) => _selectedPupilId = id,
            homeworkOnly: settings['showHomework'] == true,
            updateSetting: updateSetting,
            refresh: refresh,
          ),
    );
  }
}

class _ParentLessonsTabs extends StatefulWidget {
  final ParentLessonsOverview overview;
  final Function? openDrawerCb;
  final bool homeworkOnly;
  final UpdateSetting updateSetting;
  final RefreshFunction? refresh;
  final String? initialPupilId;
  final ValueChanged<String?> onPupilSelected;
  const _ParentLessonsTabs({
    super.key,
    required this.overview,
    required this.openDrawerCb,
    required this.homeworkOnly,
    required this.updateSetting,
    required this.refresh,
    required this.initialPupilId,
    required this.onPupilSelected,
  });
  @override
  State<_ParentLessonsTabs> createState() => _ParentLessonsTabsState();
}

class _ParentLessonsTabsState extends State<_ParentLessonsTabs>
    with TickerProviderStateMixin {
  late TabController _tabs;
  List<LessonPupil> get _pupils => widget.overview.lessonsByPupil.keys.toList();
  String? _selectedPupil;

  @override
  void initState() {
    super.initState();
    _selectedPupil = widget.initialPupilId;
    _createTabs();
  }

  void _createTabs() {
    final index = _pupils.indexWhere((pupil) => pupil.id == _selectedPupil);
    _tabs = TabController(
      length: _pupils.length,
      initialIndex: index < 0 ? 0 : index,
      vsync: this,
    );
    _selectedPupil = _pupils.isEmpty ? null : _pupils[_tabs.index].id;
    widget.onPupilSelected(_selectedPupil);
    _tabs.addListener(_selectionChanged);
  }

  void _selectionChanged() {
    if (_pupils.isEmpty || _selectedPupil == _pupils[_tabs.index].id) return;
    setState(() => _selectedPupil = _pupils[_tabs.index].id);
    widget.onPupilSelected(_selectedPupil);
  }

  @override
  void didUpdateWidget(covariant _ParentLessonsTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.overview.lessonsByPupil.keys
        .map((pupil) => pupil.id)
        .toList();
    final newIds = _pupils.map((pupil) => pupil.id).toList();
    if (!listEquals(oldIds, newIds)) {
      _tabs.dispose();
      _createTabs();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.overview.lessonsByPupil.entries.toList();
    final selected = entries.isEmpty ? null : entries[_tabs.index];
    return Scaffold(
      appBar: AppBar(
        title: Text(lessonsDefinition.label(context)),
        leading: widget.openDrawerCb == null
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              ),
        actions: [
          IconButton(
            tooltip: widget.homeworkOnly
                ? AppLocalizations.of(context).lessons
                : AppLocalizations.of(context).homework,
            icon: Icon(
              widget.homeworkOnly ? Icons.school_outlined : Icons.task_outlined,
            ),
            onPressed: () =>
                widget.updateSetting('showHomework', !widget.homeworkOnly),
          ),
        ],
        bottom: entries.isEmpty
            ? null
            : TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final entry in entries) Tab(text: entry.key.name)],
              ),
      ),
      body: entries.isEmpty
          ? Center(child: Text(AppLocalizations.of(context).noCoursesFound))
          : TabBarView(
              controller: _tabs,
              children: [
                for (final entry in entries)
                  RefreshIndicator(
                    onRefresh: widget.refresh ?? () async {},
                    child: ListView(
                      key: PageStorageKey('lessons-pupil-${entry.key.id}'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 4, bottom: 80),
                      children: _courses(
                        context,
                        entry.key,
                        entry.value,
                        widget.homeworkOnly,
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton:
          !widget.homeworkOnly &&
              selected != null &&
              selected.value.any((lesson) => lesson.attendances != null)
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => context.push(
                Uri(
                  path: '/parent/lessons/attendances',
                  queryParameters: {'pupil': selected.key.id},
                ).toString(),
              ),
              label: Text(AppLocalizations.of(context).attendances),
              icon: const Icon(Icons.access_alarm),
            )
          : null,
    );
  }

  List<Widget> _courses(
    BuildContext context,
    LessonPupil pupil,
    Lessons lessons,
    bool homeworkOnly,
  ) {
    final visible = lessons
        .where(
          (lesson) => !homeworkOnly || lesson.currentEntry?.homework != null,
        )
        .toList();
    if (visible.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(AppLocalizations.of(context).noCoursesFound),
        ),
      ];
    }
    return [
      for (final older in [false, true]) ...[
        if (older && !homeworkOnly && visible.any((lesson) => lesson.isOlder))
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(AppLocalizations.of(context).olderCourses),
          ),
        for (final lesson in visible.where((lesson) => lesson.isOlder == older))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: LessonListTile(
              lesson: lesson,
              accountType: AccountType.parent,
              pupilName: pupil.name,
            ),
          ),
      ],
    ];
  }
}
