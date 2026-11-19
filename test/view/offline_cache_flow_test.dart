import 'package:lanis/widgets/error_view.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/timetable/parent/parent_timetable_view.dart';
import 'package:lanis/applets/substitutions/substitutions_view.dart';
import 'package:lanis/utils/cached_network_image.dart';
import 'package:lanis/applets/timetable/student/student_timetable_better_view.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/features/offline/cached_data_source.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/widgets/offline_available_applets_section.dart';
import '../helpers/test_app.dart';

class _ForbiddenSession extends Session {
  @override
  FutureOr<LanisSession?> build() =>
      throw StateError('Offline view created a session');
}

class _OfflineAuth extends AuthController {
  @override
  AuthState build() => AuthState.error(NoConnectionException());
}

TimeTable plan() => TimeTable(
  planForAll: [[], [], [], [], []],
  hours: [
    TimeTableRow(
      TimeTableRowType.lesson,
      const SphTimeOfDay(hour: 8, minute: 0),
      const SphTimeOfDay(hour: 9, minute: 0),
      '1',
      0,
    ),
  ],
);

void main() {
  tearDown(resetAuthTestSeams);
  ProviderContainer container() {
    final result = ProviderContainer(
      overrides: [
        ...testLanisOverrides(),
        sessionProvider.overrideWith(_ForbiddenSession.new),
        connectionCheckerProvider.overrideWith(
          (ref) =>
              throw StateError('Offline view constructed the online checker'),
        ),
        authControllerProvider.overrideWith(_OfflineAuth.new),
        storageManagerProvider.overrideWith(
          (ref) => throw StateError(
            'Offline view constructed session-dependent storage',
          ),
        ),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  Future<void> pump(WidgetTester tester, ProviderContainer scope) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: const Scaffold(body: OfflineAvailableAppletsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cached timetable opens with no session, checker, active account, or auth transition',
    (tester) async {
      final scope = container();
      final id = await addTestAccount(scope);
      await scope
          .read(cacheServiceProvider)
          .execute(
            accountId: id,
            request: TimetableStudentParserCacheRequests.getHome(),
            load: () async => plan(),
          );
      await pump(tester, scope);
      expect(find.byType(ListTile), findsOneWidget);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byType(StudentTimetableBetterView), findsOneWidget);
      expect(scope.read(activeAccountProvider), isNull);
      expect(scope.read(authControllerProvider).phase, AuthPhase.error);
      expect(AuthController.authenticateCallCount, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final cacheSecond in [false, true]) {
    testWidgets(
      'parent timetable prepares cached children (second cached: $cacheSecond)',
      (tester) async {
        final scope = container();
        final id = await addTestAccount(scope, accountType: AccountType.parent);
        final refs = [
          for (var i = 1; i <= 2; i++)
            ParentTimetableReference(
              pupilId: '$i',
              pupilName: 'Child $i',
              className: '1',
              url: Uri.parse('stundenplan.php?a=detail_klasse&k=1&p=$i'),
            ),
        ];
        final cache = scope.read(cacheServiceProvider);
        await cache.execute(
          accountId: id,
          request: TimetableParentParserCacheRequests.getHome(),
          load: () async => ParentTimetableSelection(timetables: refs),
        );
        await cache.execute(
          accountId: id,
          request: TimetableParentParserCacheRequests.getTimetable(refs.first),
          load: () async =>
              ParentTimetableLoaded(pupilId: '1', timetable: plan()),
        );
        if (cacheSecond) {
          await cache.execute(
            accountId: id,
            request: TimetableParentParserCacheRequests.getTimetable(refs.last),
            load: () async =>
                ParentTimetableLoaded(pupilId: '2', timetable: plan()),
          );
        }
        await pump(tester, scope);
        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();
        expect(find.byType(ParentTimetableView), findsOneWidget);
        expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
        expect(find.byType(StudentTimetableBetterView), findsOneWidget);
        expect(
          find.byIcon(Icons.error_outline),
          cacheSecond ? findsNothing : findsOneWidget,
        );
        await tester.tap(find.text('Child 2'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pumpAndSettle();
        expect(
          find.byType(OfflineDataUnavailableView),
          cacheSecond ? findsNothing : findsOneWidget,
        );
        expect(find.text('Try again'), findsNothing);
        expect(find.text('Stack Trace'), findsNothing);
        await tester.tap(find.text('Child 1'));
        await tester.pumpAndSettle();
        expect(find.byType(StudentTimetableBetterView), findsOneWidget);
        expect(scope.read(authControllerProvider).phase, AuthPhase.error);
        expect(scope.read(activeAccountProvider), isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'loaded parent home displays its own plan without a separate detail entry',
    (tester) async {
      final scope = container();
      final id = await addTestAccount(scope, accountType: AccountType.parent);
      await scope
          .read(cacheServiceProvider)
          .execute(
            accountId: id,
            request: TimetableParentParserCacheRequests.getHome(),
            load: () async =>
                ParentTimetableLoaded(pupilId: '1', timetable: plan()),
          );
      await pump(tester, scope);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byType(StudentTimetableBetterView), findsOneWidget);
      expect(scope.read(authControllerProvider).phase, AuthPhase.error);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'offline notice images and fullscreen routes keep local-only providers',
    (tester) async {
      final scope = container();
      final id = await addTestAccount(scope);
      await scope
          .read(cacheServiceProvider)
          .execute(
            accountId: id,
            request: SubstitutionsParserCacheRequests.getHome(),
            load: () async => SubstitutionPlan(
              days: [
                SubstitutionDay(
                  parsedDate: '17.11.2026',
                  infos: [
                    SubstitutionInfo(
                      header: 'Notice',
                      values: [
                        '<img src="https://example.invalid/offline.png">',
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
      await pump(tester, scope);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      final label = AppLocalizations.of(
        tester.element(find.byType(SubstitutionsView)),
      ).substitutionsInformationMessage;
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      await tester.tap(find.byIcon(Icons.image_not_supported_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FullScreenImageView), findsOneWidget);
      expect(scope.read(activeAccountProvider), isNull);
      expect(scope.read(authControllerProvider).phase, AuthPhase.error);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('expired homes and detail-only entries create no module tile', (
    tester,
  ) async {
    final scope = container();
    final id = await addTestAccount(scope, accountType: AccountType.parent);
    final db = scope.read(lanisDatabaseProvider);
    final home = TimetableParentParserCacheRequests.getHome();
    final fetched = DateTime.now().subtract(const Duration(days: 8));
    db.writeCacheRecord(
      CacheRecord(
        key: home.keyFor(id),
        codecId: home.codec.id,
        json: '{}',
        fetchedAt: fetched,
        expiresAt: fetched.add(const Duration(hours: 1)),
      ),
      db.cacheGeneration(id),
    );
    final reference = ParentTimetableReference(
      pupilId: '1',
      pupilName: 'Child',
      className: '1',
      url: Uri.parse('stundenplan.php?a=detail_klasse&p=1'),
    );
    await scope
        .read(cacheServiceProvider)
        .execute(
          accountId: id,
          request: TimetableParentParserCacheRequests.getTimetable(reference),
          load: () async =>
              ParentTimetableLoaded(pupilId: '1', timetable: plan()),
        );
    await pump(tester, scope);
    expect(find.byType(ListTile), findsNothing);
    expect(scope.read(activeAccountProvider), isNull);
  });

  test(
    'local data source stops displaying a snapshot after it expires',
    () async {
      final scope = container();
      final id = await addTestAccount(scope);
      var now = DateTime.now().toUtc();
      final cache = CacheService(
        scope.read(lanisDatabaseProvider),
        clock: () => now,
      );
      final request = TimetableStudentParserCacheRequests.getHome();
      await cache.execute(
        accountId: id,
        request: request,
        load: () async => plan(),
      );
      final source = CachedDataSource(
        read: () => cache.readCacheFor(accountId: id, request: request),
      );
      addTearDown(source.dispose);
      await source.fetchData();
      expect(source.latestResponse.status, FetcherStatus.done);
      now = now.add(const Duration(days: 7));
      await source.fetchData(forceRefresh: true);
      expect(source.latestResponse.status, FetcherStatus.error);
      expect(source.latestResponse.content, isNull);
    },
  );
  test(
    'data source preserves online errors and labels local misses offline',
    () async {
      final error = UnknownException('parsing failed');
      final online = CachedDataSource<int>(read: () async => throw error);
      final offline = CachedDataSource<int>(
        cacheOnly: true,
        read: () async =>
            throw CacheUnavailableException(CacheEntryState.missing),
      );
      addTearDown(online.dispose);
      addTearDown(offline.dispose);
      await online.fetchData();
      await offline.fetchData();
      expect(online.latestResponse.contentStatus, ContentStatus.online);
      expect(online.latestResponse.error!.exception, same(error));
      expect(offline.latestResponse.contentStatus, ContentStatus.offline);
      expect(
        offline.latestResponse.error!.exception,
        isA<CacheUnavailableException>(),
      );
    },
  );
}
