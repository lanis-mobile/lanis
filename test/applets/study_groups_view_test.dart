import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/study_groups/routes.dart';

import '../helpers/test_app.dart';

class _FakeStudyGroupsSource implements AppletDataSource<StudentStudyGroups> {
  final StudentStudyGroups data;
  final _controller =
      StreamController<FetcherResponse<StudentStudyGroups>>.broadcast();
  FetcherResponse<StudentStudyGroups>? _latest;

  _FakeStudyGroupsSource(this.data);

  @override
  Stream<FetcherResponse<StudentStudyGroups>> get stream => _controller.stream;

  @override
  FetcherResponse<StudentStudyGroups>? get latestResponse => _latest;

  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    _latest = FetcherResponse(
      status: FetcherStatus.done,
      error: null,
      content: data,
    );
    _controller.add(_latest!);
  }

  @override
  void startAutoRefresh() {}

  @override
  void stopAutoRefresh() {}

  void dispose() => _controller.close();
}

StudentStudyGroups _sampleData() {
  final exam = StudentStudyGroupExam(
    id: '9104',
    courseId: '4821',
    courseName: 'Mathematik LK',
    date: DateTime.now().add(const Duration(days: 5)),
    type: '2. Klausur',
    hoursOfDay: '1.-3. Std.',
    durationLabel: '135 Min.',
  );
  return StudentStudyGroups(
    groups: [
      StudentStudyGroup(
        id: '4821',
        semester: '2026/27 (1. Hj.)',
        courseName: 'Mathematik LK',
        courseSysId: 'M-LK-1',
        teachers: [
          StudentStudyGroupTeacher(
            krz: 'MUE',
            firstName: 'Max',
            lastName: 'Müller',
            email: 'm.mueller@schule.hessen.de',
          ),
        ],
        exams: [exam],
      ),
    ],
    exams: [exam],
  );
}

void main() {
  tearDown(resetAuthTestSeams);

  testWidgets(
    'StudyGroupsModePage switches between study groups and exams via SegmentedButton and swipe',
    (tester) async {
      final source = _FakeStudyGroupsSource(_sampleData());
      addTearDown(source.dispose);

      await pumpTestApp(
        tester,
        child: StudyGroupsModePage(dataSource: source),
      );
      await tester.pumpAndSettle();

      // Initially on Study groups page (index 0).
      final seg = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(seg.selected, {0});
      expect(find.text('M-LK-1'), findsOneWidget);

      // Tap Exams segment to switch to Exams page (index 1).
      await tester.tap(find.text('Exams'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {1},
      );
      expect(find.text('1.-3. Std. (135 Min.)'), findsOneWidget);

      // Swipe right to return to Study groups page (index 0).
      await tester.fling(find.byType(PageView), const Offset(500, 0), 1000);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {0},
      );
      expect(find.text('M-LK-1'), findsOneWidget);

      // Swipe left to switch back to Exams page (index 1).
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {1},
      );
      expect(find.text('1.-3. Std. (135 Min.)'), findsOneWidget);
    },
  );
}
