import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/parent/parent_timetable_view.dart';
import 'package:lanis/applets/timetable/timetable_settings_page.dart';
import 'package:lanis/applets/timetable/timetable_settings_scope.dart';
import 'package:lanis/applets/timetable/timetable_modifications_editor.dart';
import 'package:lanis/generated/l10n.dart';
import '../helpers/test_app.dart';
import '../helpers/timetable_fixture.dart';

class _Session implements LanisSession {
  final AccountType type;
  _Session(this.type);
  @override
  AccountType get accountTypeOrNull => type;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadySession extends Session {
  final AccountType type;
  _ReadySession(this.type);
  @override
  LanisSession build() => _Session(type);
}

class _ParentParser extends TimetableParentParser {
  final bool single;
  final requests = <String>[];
  _ParentParser(super.context, {this.single = false})
    : super(isConnected: () async => true);
  @override
  Future<ParentTimetableHome> getHome() async => single
      ? ParentTimetableLoaded(
          pupilId: '1',
          pupilName: 'Child 1',
          timetable: timetable(),
        )
      : ParentTimetableSelection(
          timetables: [
            for (final id in ['1', '2'])
              ParentTimetableReference(
                pupilId: id,
                pupilName: 'Child $id',
                className: 'Class',
                url: Uri.parse('stundenplan.php?a=detail_klasse&p=$id'),
              ),
          ],
        );
  @override
  Future<ParentTimetableLoaded> getTimetable(
    ParentTimetableReference reference,
  ) async {
    requests.add(reference.pupilId);
    return ParentTimetableLoaded(
      pupilId: reference.pupilId,
      timetable: timetable(),
    );
  }
}

class _StudentParser extends TimetableStudentParser {
  _StudentParser(super.context) : super(isConnected: () async => true);
  @override
  Future<TimeTable> getHome() async => timetable();
}

void main() {
  tearDown(LanisClient.reset);
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool student = false,
    bool single = false,
    bool editing = true,
  }) async {
    tester.view.physicalSize = const Size(450, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final type = student ? AccountType.student : AccountType.parent;
    late _ParentParser parent;
    late _StudentParser pupil;
    final scope = ProviderContainer(
      overrides: [
        ...testLanisOverrides(),
        sessionProvider.overrideWith(() => _ReadySession(type)),
        timetableParentParserProvider.overrideWith((ref) {
          if (student) throw StateError('Student used parent parser');
          return parent;
        }),
        timetableParserProvider.overrideWith((ref) {
          if (!student) throw StateError('Parent used student parser');
          return pupil;
        }),
      ],
    );
    addTearDown(scope.dispose);
    final id = await addTestAccount(scope, accountType: type);
    await scope.read(activeAccountProvider.notifier).select(id);
    final context = scope.read(appletContextProvider);
    parent = _ParentParser(context, single: single);
    pupil = _StudentParser(context);
    addTearDown(parent.dispose);
    addTearDown(pupil.dispose);
    final base = scope.read(accountSpecificSettingsProvider)!;
    base.setJsonList('stundenplan.php/custom-lessons', [
      [lesson('Account original', 8).toJson()],
    ]);
    timetableSettingsForPupil(base, '1')!.setJsonList(
      'stundenplan.php/custom-lessons',
      [
        [lesson('Only child one', 9).toJson()],
      ],
    );
    timetableSettingsForPupil(
      base,
      '1',
    )!.setJsonList('stundenplan.php/hidden-lessons', ['maths']);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: editing
              ? const TimetableSettingsPage()
              : const ParentTimetableView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return scope;
  }

  testWidgets(
    'student uses the same unified editor and its existing account settings',
    (tester) async {
      await pump(tester, student: true);
      expect(find.byType(TimetableModificationsEditor), findsOneWidget);
      expect(find.text('Account original'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final single in [false, true]) {
    testWidgets(
      'parent editor scopes to the child (single loaded home: $single)',
      (tester) async {
        final scope = await pump(tester, single: single);
        expect(find.byType(TimetableModificationsEditor), findsOneWidget);
        expect(find.text('Only child one'), findsOneWidget);
        expect(find.text('Account original'), findsNothing);
        final base = scope.read(accountSpecificSettingsProvider)!;
        if (single) {
          expect(find.byType(TabBar), findsNothing);
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text('Child 1'),
            ),
            findsOneWidget,
          );
        } else {
          expect(
            tester.widget<TabBar>(find.byType(TabBar)).isScrollable,
            isTrue,
          );
          await tester.tap(find.text('Child 2'));
          await tester.pumpAndSettle();
          expect(find.text('Only child one'), findsNothing);
        }
        await tester.tap(find.byKey(const ValueKey('add-custom-lesson')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('custom-lesson-name')),
          'New activity',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('save-custom-lesson')),
        );
        await tester.tap(find.byKey(const ValueKey('save-custom-lesson')));
        await tester.pumpAndSettle();
        final child = single ? '1' : '2';
        final saved = timetableSettingsForPupil(
          base,
          child,
        )!.getJsonList('stundenplan.php/custom-lessons')!;
        expect(
          saved
              .expand((day) => day as List)
              .where((entry) => entry['name'] == 'New activity'),
          hasLength(1),
        );
        expect(
          base
              .getJsonList('stundenplan.php/custom-lessons')!
              .first
              .single['name'],
          'Account original',
        );
        if (!single) {
          await tester.tap(find.text('Child 1'));
          await tester.pumpAndSettle();
          expect(find.text('Only child one'), findsOneWidget);
          expect(find.text('New activity'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'parent timetable renders only the selected child\'s custom entries',
    (tester) async {
      await pump(tester, editing: false);
      expect(find.text('Only child one'), findsOneWidget);
      expect(find.text('School maths'), findsNothing);
      expect(find.text('Account original'), findsNothing);
      await tester.tap(find.text('Child 2'));
      await tester.pumpAndSettle();
      expect(find.text('Only child one'), findsNothing);
      expect(find.text('School maths'), findsOneWidget);
      expect(find.text('Account original'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'returning from the editor updates the existing timetable immediately',
    (tester) async {
      await pump(tester, single: true, editing: false);
      expect(find.text('Only child one'), findsOneWidget);
      final context = tester.element(find.byType(ParentTimetableView));
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TimetableSettingsPage()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('custom-lesson-name')),
        'Changed activity',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-custom-lesson')),
      );
      await tester.tap(find.byKey(const ValueKey('save-custom-lesson')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(TimetableSettingsPage))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Only child one'), findsNothing);
      expect(find.text('Changed activity'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
