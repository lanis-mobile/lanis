import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/lessons/parent/lessons_parent_view.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/router.dart';
import 'package:lanis/utils/deep_link.dart';
import '../helpers/test_app.dart';

class _Authenticated extends AuthController {
  @override
  AuthState build() => const AuthState.authenticated();
}

class _Context implements AppletContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

class _Lessons extends LessonsParentParser {
  _Lessons() : super(_Context(), isConnected: () async => true);
  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    addResponse(
      FetcherResponse(
        status: FetcherStatus.done,
        error: null,
        content: ParentLessonsOverview(
          lessonsByPupil: {const LessonPupil(id: '1', name: 'Test child'): []},
        ),
      ),
    );
  }
}

void main() {
  tearDown(LanisClient.reset);
  testWidgets('shell created before login opens and reselects parent Lessons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final parser = _Lessons();
    addTearDown(parser.dispose);
    final scope = ProviderContainer(
      overrides: [
        ...testLanisOverrides(),
        authControllerProvider.overrideWith(_Authenticated.new),
        sessionProvider.overrideWith(_ReadySession.new),
        supportedAppletPhpUrlsProvider.overrideWith(
          (ref) => {'meinunterricht.php'},
        ),
        lessonsParentParserProvider.overrideWithValue(parser),
      ],
    );
    addTearDown(scope.dispose);
    // The production router is normally created on startup, before account selection.
    final production = scope.read(goRouterProvider);
    addTearDown(production.dispose);
    final shell = production.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;
    final branch = shell.branches.firstWhere(
      (branch) => branch.routes.any(
        (route) => route is GoRoute && route.path == '/parent/lessons',
      ),
    );
    final id = await addTestAccount(scope, accountType: AccountType.parent);
    acceptPrivacy(scope);
    await scope.read(activeAccountProvider.notifier).select(id);
    final router = GoRouter(
      initialLocation: '/ready',
      redirect: production.configuration.topRedirect,
      routes: [
        GoRoute(
          path: SettingsDeepLinks.deepLinkError,
          builder: (_, _) => const Scaffold(body: Text('Wrong-account error')),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigation) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  onPressed: () => navigation.goBranch(
                    1,
                    initialLocation: navigation.currentIndex == 1,
                  ),
                  child: const Text('Open Lessons'),
                ),
                Expanded(child: navigation),
              ],
            ),
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/ready', builder: (_, _) => const SizedBox()),
              ],
            ),
            branch,
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Lessons'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/parent/lessons/home',
    );
    expect(find.byType(LessonsParentView), findsOneWidget);
    expect(find.text('Wrong-account error'), findsNothing);
    await tester.tap(find.text('Open Lessons'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/parent/lessons/home',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
