import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/timetable/teacher/teacher_timetable_models.dart';
import 'package:lanis/applets/timetable/teacher/teacher_timetable_panels.dart';
import 'package:lanis/applets/timetable/timetable_version_button.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(appBar: AppBar(actions: [child])),
  );
}

void main() {
  const versions = [
    TimetableVersion(
      date: '2026-12-11',
      label: 'ab 11.12.2026',
      isSelected: false,
    ),
    TimetableVersion(
      date: '2026-11-23',
      label: 'ab 23.11.2026 (bis 10.12.2026)',
      isSelected: true,
    ),
  ];

  testWidgets('hides itself when fewer than 2 versions are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TimetableVersionButton(
          versions: const [
            TimetableVersion(
              date: '2026-11-23',
              label: 'ab 23.11.2026',
              isSelected: true,
            ),
          ],
          selectedDate: '2026-11-23',
          onSelected: (_) {},
        ),
      ),
    );
    expect(find.byType(MenuAnchor), findsNothing);
  });

  testWidgets('renders compact pill and opens popover menu to select version', (
    tester,
  ) async {
    TimetableVersion? picked;
    await tester.pumpWidget(
      _wrap(
        TimetableVersionButton(
          versions: versions,
          selectedDate: '2026-11-23',
          defaultDate: '2026-11-23',
          onSelected: (v) => picked = v,
        ),
      ),
    );

    // Pill strips parenthetical end-date suffix.
    expect(find.text('ab 23.11.2026'), findsOneWidget);
    expect(find.text('ab 11.12.2026'), findsNothing);

    // Tap pill -> popover opens with full labels.
    await tester.tap(find.text('ab 23.11.2026'));
    await tester.pumpAndSettle();

    expect(find.text('ab 23.11.2026 (bis 10.12.2026)'), findsOneWidget);
    expect(find.text('ab 11.12.2026'), findsOneWidget);

    // Tap alternate version -> invokes callback.
    await tester.tap(find.text('ab 11.12.2026'));
    await tester.pumpAndSettle();

    expect(picked, versions.first);
  });

  test('formatPillLabel shortens verbose labels in compact mode', () {
    expect(
      TimetableVersionButton.formatPillLabel(versions[1], compact: false),
      'ab 23.11.2026',
    );
    expect(
      TimetableVersionButton.formatPillLabel(versions[1], compact: true),
      'ab 23.11.',
    );
  });

  test('plainNoticeText strips hyperlink and button action labels', () {
    const html =
        '<b>Eine oder mehrere Lerngruppen sind noch nicht mit dem Stundenplan verknüpft. &nbsp;</b> '
        '<a href="stundenplan.php?e=1&a=verknuepfen" class="btn btn-default">'
        '<i class="fa fa-pencil"></i> hinterlegte Lerngruppen ändern</a>';
    expect(
      plainNoticeText(html),
      'Eine oder mehrere Lerngruppen sind noch nicht mit dem Stundenplan verknüpft.',
    );
  });

  testWidgets('disables menu items when isVersionEnabled returns false', (
    tester,
  ) async {
    TimetableVersion? picked;
    await tester.pumpWidget(
      _wrap(
        TimetableVersionButton(
          versions: versions,
          selectedDate: '2026-11-23',
          defaultDate: '2026-11-23',
          isVersionEnabled: (v) => v.date == '2026-11-23',
          onSelected: (v) => picked = v,
        ),
      ),
    );

    await tester.tap(find.text('ab 23.11.2026'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ab 11.12.2026'));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });

  testWidgets('TeacherPlanCatalogPanel disables uncached targets offline', (
    tester,
  ) async {
    final teacherCached = TeacherTimetableReference(
      category: TeacherTimetableCategory.teacher,
      id: 'CAP',
      label: 'Cached Teacher (CAP)',
      url: Uri.parse('https://example.org/stundenplan.php?a=teacher&t=CAP'),
    );
    final teacherUncached = TeacherTimetableReference(
      category: TeacherTimetableCategory.teacher,
      id: 'CAP2',
      label: 'Uncached Teacher (CAP2)',
      url: Uri.parse('https://example.org/stundenplan.php?a=teacher&t=CAP2'),
    );
    final roomUncached = TeacherTimetableReference(
      category: TeacherTimetableCategory.room,
      id: 'R101',
      label: 'R101',
      url: Uri.parse('https://example.org/stundenplan.php?a=room&r=R101'),
    );
    final overview = TeacherTimetableOverview(
      teachers: [teacherCached, teacherUncached],
      classes: const [],
      rooms: [roomUncached],
      breakSupervisions: const [],
      canViewOtherTeachers: true,
    );
    final selectedTargets = <TeacherTimetableTarget>[];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TeacherPlanCatalogPanel(
            overview: overview,
            ownTarget: null,
            activeTarget: TeacherTimetableTarget(reference: teacherCached),
            expandedCategories: const {
              TeacherTimetableCategory.teacher,
              TeacherTimetableCategory.room,
            },
            isTargetEnabled: (t) => t.id == 'CAP',
            onToggleCategory: (_) {},
            onSelectTarget: selectedTargets.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Uncached Teacher (CAP2)'));
    await tester.tap(find.text('R101'));
    await tester.pump();
    expect(selectedTargets, isEmpty);

    await tester.tap(find.text('Cached Teacher (CAP)'));
    await tester.pump();
    expect(selectedTargets.map((t) => t.id), ['CAP']);
  });
}
