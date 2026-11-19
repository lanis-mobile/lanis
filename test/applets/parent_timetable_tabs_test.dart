import 'package:lanis/widgets/error_view.dart';
import 'dart:async';
import 'package:lanis/widgets/offline_banner.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/parent/parent_timetable_view.dart';
import 'package:lanis/applets/timetable/student/student_timetable_better_view.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/features/offline/foreground_connection_monitor.dart';
import '../helpers/test_app.dart';

class _Session implements LanisSession {
  @override
  AccountType get accountTypeOrNull => AccountType.parent;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadySession extends Session {
  @override
  LanisSession build() => _Session();
}

TimeTable plan(String id) =>
    TimeTable(hours: [], planForAll: [[], [], [], [], []], weekBadge: id);

class _Parser extends TimetableParentParser {
  int count;
  final bool loaded;
  int homeCalls = 0;
  bool offline;
  Completer<void>? homeGate;
  final requests = <String>[];
  _Parser(
    super.context, {
    this.count = 2,
    this.loaded = false,
    this.offline = false,
    this.homeGate,
  }) : super(isConnected: () async => true);
  @override
  Future<ParentTimetableHome> getHome() async {
    homeCalls++;
    await homeGate?.future;
    if (offline) throw NoConnectionException();
    if (loaded) {
      return ParentTimetableLoaded(
        pupilId: '1',
        pupilName: 'Child 1',
        timetable: plan('1'),
      );
    }
    return ParentTimetableSelection(
      timetables: [
        for (var i = 1; i <= count; i++)
          ParentTimetableReference(
            pupilId: '$i',
            pupilName: 'Child $i',
            className: 'Class',
            url: Uri.parse('stundenplan.php?a=detail_klasse&p=$i'),
          ),
      ],
    );
  }

  @override
  Future<ParentTimetableLoaded> getTimetable(
    ParentTimetableReference reference,
  ) async {
    requests.add(reference.pupilId);
    if (offline) throw NoConnectionException();
    return ParentTimetableLoaded(
      pupilId: reference.pupilId,
      timetable: plan(reference.pupilId),
    );
  }
}

void main() {
  tearDown(LanisClient.reset);
  Future<_Parser> pump(
    WidgetTester tester, {
    int count = 2,
    bool loaded = false,
    bool seedHome = false,
    bool offline = false,
    bool settle = true,
    Completer<void>? homeGate,
    Function? openDrawerCb,
  }) async {
    late _Parser parser;
    final scope = ProviderContainer(
      overrides: [
        ...testLanisOverrides(),
        sessionProvider.overrideWith(_ReadySession.new),
        timetableParentParserProvider.overrideWith((ref) => parser),
      ],
    );
    addTearDown(scope.dispose);
    final id = await addTestAccount(scope, accountType: AccountType.parent);
    await scope.read(activeAccountProvider.notifier).select(id);
    parser = _Parser(
      scope.read(appletContextProvider),
      count: count,
      loaded: loaded,
      offline: offline,
      homeGate: homeGate,
    );
    addTearDown(parser.dispose);
    if (seedHome) {
      await scope
          .read(cacheServiceProvider)
          .execute(
            accountId: id,
            request: TimetableParentParserCacheRequests.getHome(),
            load: () async =>
                ParentTimetableLoaded(pupilId: '1', timetable: plan('old')),
          );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: GlobalOfflineShell(
            child: ParentTimetableView(openDrawerCb: openDrawerCb),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return parser;
  }

  testWidgets(
    'parent timetable keeps title and drawer during overview loading and offline error',
    (tester) async {
      var opened = 0;
      final gate = Completer<void>();
      final parser = await pump(
        tester,
        offline: true,
        settle: false,
        homeGate: gate,
        openDrawerCb: () => opened++,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Timetable'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.menu));
      expect(opened, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Timetable'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.menu));
      expect(opened, 2);
      parser.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Child 1'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('empty parent timetable keeps title and drawer', (tester) async {
    var opened = 0;
    await pump(tester, count: 0, openDrawerCb: () => opened++);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Timetable'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.menu));
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'first plan loads automatically; other tabs load only on selection',
    (tester) async {
      final parser = await pump(tester);
      expect(parser.homeCalls, 1);
      expect(parser.requests, ['1']);
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
      await tester.tap(find.text('Child 2'));
      await tester.pumpAndSettle();
      expect(parser.requests, ['1', '2']);
      expect(
        tester
            .widget<StudentTimetableBetterView>(
              find.byType(StudentTimetableBetterView),
            )
            .dataSource!
            .latestResponse!
            .content!
            .weekBadge,
        '2',
      );
      await tester.tap(find.text('Child 1'));
      await tester.pumpAndSettle();
      expect(parser.requests, ['1', '2']);
      expect(
        tester
            .widget<StudentTimetableBetterView>(
              find.byType(StudentTimetableBetterView),
            )
            .dataSource!
            .latestResponse!
            .content!
            .weekBadge,
        '1',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('one selection loads its only timetable', (tester) async {
    final parser = await pump(tester, count: 1);
    expect(parser.requests, ['1']);
    expect(find.byType(TabBar), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Child 1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a single-child loaded home needs no duplicate detail request', (
    tester,
  ) async {
    final parser = await pump(tester, loaded: true);
    expect(parser.homeCalls, 1);
    expect(parser.requests, isEmpty);
    expect(find.byType(TabBar), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Child 1')),
      findsOneWidget,
    );
    expect(find.byType(StudentTimetableBetterView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'single-child home replaces its immediate cached preview with fresh data',
    (tester) async {
      final parser = await pump(tester, loaded: true, seedHome: true);
      expect(parser.homeCalls, 1);
      expect(parser.requests, isEmpty);
      final response = tester
          .widget<StudentTimetableBetterView>(
            find.byType(StudentTimetableBetterView),
          )
          .dataSource!
          .latestResponse!;
      expect(response.content!.weekBadge, '1');
      expect(response.contentStatus, ContentStatus.online);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'foreground loss, resume, child switches and recovery retain the right saved plan',
    (tester) async {
      final parser = await pump(tester, count: 3);
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(ParentTimetableView)),
      );
      final checker = scope.read(connectionCheckerProvider);
      checker.status = ConnectionStatus.connected;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Child 2'));
      await tester.pumpAndSettle();
      expect(parser.requests, ['1', '2']);
      final original = tester
          .widget<StudentTimetableBetterView>(
            find.byType(StudentTimetableBetterView),
          )
          .dataSource!
          .latestResponse!
          .fetchedAt;
      parser.offline = true;
      scope.read(networkInterfaceAvailableProvider.notifier).update(false);
      checker.status = ConnectionStatus.disconnected;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Offline')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(AppBar)).dy),
      );
      final restored = tester
          .widget<StudentTimetableBetterView>(
            find.byType(StudentTimetableBetterView),
          )
          .dataSource!
          .latestResponse!;
      expect(restored.content!.weekBadge, '2');
      expect(restored.fetchedAt, original);
      await tester.tap(find.text('Child 1'));
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Offline')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(AppBar)).dy),
      );
      await tester.tap(find.text('Child 3'));
      await tester.pumpAndSettle();
      expect(parser.requests, ['1', '2']);
      expect(find.byType(OfflineDataUnavailableView), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Stack Trace'), findsNothing);
      parser.offline = false;
      scope.read(networkInterfaceAvailableProvider.notifier).update(true);
      checker.status = ConnectionStatus.connected;
      await tester.pumpAndSettle();
      expect(parser.requests, ['1', '2', '3']);
      expect(
        tester
            .widget<StudentTimetableBetterView>(
              find.byType(StudentTimetableBetterView),
            )
            .dataSource!
            .latestResponse!
            .content!
            .weekBadge,
        '3',
      );
      expect(find.text('Offline'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'overflowing tabs can reach a later child without loading intermediate plans',
    (tester) async {
      final parser = await pump(tester, count: 24);
      await tester.ensureVisible(find.text('Child 24'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Child 24'));
      await tester.pumpAndSettle();
      expect(parser.requests, ['1', '24']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
