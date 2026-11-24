import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/conversations/conversations_nav.dart';
import 'package:lanis/applets/conversations/view/chat.dart';
import 'package:lanis/applets/conversations/view/conversations_view.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/applets/substitutions/substitutions_view.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/l10n/locale_resolution.dart';
import 'package:lanis/router.dart';
import 'package:lanis/themes.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/notification_navigation.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_app.dart';

class _OnlineChecker extends ConnectionChecker {
  @override
  Future<bool> testConnection() async => true;
}

class _FakeSubstitutionsParser extends SubstitutionsParser {
  _FakeSubstitutionsParser(super.ctx)
    : super(isConnected: () async => true);

  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    addResponse(
      FetcherResponse(
        status: FetcherStatus.done,
        error: null,
        content: SubstitutionPlan(),
      ),
    );
  }
}

class _FakeConversationsParser extends ConversationsParser {
  _FakeConversationsParser(super.ctx)
    : super(isConnected: () async => true) {
    cachedCanChooseType = false;
  }

  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    addResponse(
      FetcherResponse(
        status: FetcherStatus.done,
        error: null,
        content: const <OverviewEntry>[],
      ),
    );
  }

  @override
  Future<Conversation> getSingleConversation(String uniqueID) async {
    return Conversation(
      groupChat: false,
      onlyPrivateAnswers: false,
      noReply: true,
      parent: const UnparsedMessage(
        id: 'parent-1',
        date: '24.11.2026 08:00:00',
        author: 'Teacher',
        own: false,
        content: '<p>Hello</p>',
      ),
      countParents: 0,
      countStudents: 1,
      countTeachers: 1,
      knownParticipants: const [],
      msgLastRefresh: 0,
    );
  }
}

Future<void> _pumpRouterApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
  BubbleStyles.init(Themes.standardTheme.lightTheme!);
  container.read(notificationNavigationDriverProvider);
  final router = container.read(goRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: Themes.standardTheme.lightTheme,
        locale: const Locale('en'),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: resolveAppLocale,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
}

Future<ProviderContainer> _createNotificationTestContainer({
  required NotificationNavigationCoordinator coordinator,
}) async {
  final db = LanisDatabase.open();
  final checker = _OnlineChecker();
  final dummyAccount = const ClearTextAccount(
    localId: 1,
    schoolID: 1,
    username: 'u',
    password: 'p',
    schoolName: 'School',
  );
  final dummySession = LanisSession(
    account: dummyAccount,
    config: const LanisConfig(),
    connectionChecker: checker,
  );
  final ctx = AppletContext(
    session: dummySession,
    database: db,
    account: dummyAccount,
    accountSettings: TypedSettings.account(db, 1),
  );
  final substitutionsParser = _FakeSubstitutionsParser(ctx);
  final conversationsParser = _FakeConversationsParser(ctx);

  final container = ProviderContainer(
    overrides: [
      ...testLanisOverrides(),
      connectionCheckerProvider.overrideWithValue(checker),
      notificationNavigationProvider.overrideWithValue(coordinator),
      supportedAppletPhpUrlsProvider.overrideWith(
        (ref) => {'vertretungsplan.php', 'nachrichten.php', 'meinunterricht.php'},
      ),
      substitutionsParserProvider.overrideWithValue(substitutionsParser),
      conversationsParserProvider.overrideWithValue(conversationsParser),
    ],
  );
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const flnChannel = MethodChannel('dexterous.com/flutter/local_notifications');

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Lanis',
      packageName: 'lanis',
      version: '4.5.0',
      buildNumber: '99',
      buildSignature: '',
      installerStore: null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          permissionsChannel,
          (_) async => <int, int>{17: 1},
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(flnChannel, null);
    debugDefaultTargetPlatformOverride = null;
    NotificationNavigationCoordinator.instance.reset();
    resetAuthTestSeams();
  });

  group('normalizeNotificationRedirectUri & NotificationNavigationPayload', () {
    test('normalizes valid internal paths and lanis:// URIs', () {
      expect(
        normalizeNotificationRedirectUri('/common/substitutions/home'),
        '/common/substitutions/home',
      );
      expect(
        normalizeNotificationRedirectUri(
          '  /common/conversations/chat/42?title=Hello%20World  ',
        ),
        '/common/conversations/chat/42?title=Hello%20World',
      );
      expect(
        normalizeNotificationRedirectUri('lanis://common/conversations/home'),
        '/common/conversations/home',
      );
      expect(
        normalizeNotificationRedirectUri(
          'lanis:///student/lessons/course/99?title=Math',
        ),
        '/student/lessons/course/99?title=Math',
      );
    });

    test('rejects invalid, foreign, protocol-relative, and auth routes', () {
      for (final raw in [
        null,
        '',
        '   ',
        '//evil.example/common/substitutions/home',
        'https://evil.example/common/substitutions/home',
        'javascript:alert(1)',
        '/startup',
        '/welcome',
        '/login',
        '/privacy-policy',
        '/accounts',
        '/deep-link-error',
        '/unknown/foo',
        'lanis://',
        'lanis://unknown/foo',
      ]) {
        expect(
          normalizeNotificationRedirectUri(raw),
          isNull,
          reason: 'Expected null for $raw',
        );
      }
    });

    test('round-trips JSON payload and drops malformed payloads', () {
      const payload = NotificationNavigationPayload(
        redirectUri: '/common/conversations/chat/abc?title=Hi',
        accountId: 7,
      );
      final encoded = payload.encode();
      final decoded = NotificationNavigationPayload.tryParse(encoded);
      expect(decoded, equals(payload));

      expect(
        NotificationNavigationPayload.tryParse(
          '{"redirectUri":"lanis://common/substitutions/home"}',
        ),
        equals(
          const NotificationNavigationPayload(
            redirectUri: '/common/substitutions/home',
            accountId: null,
          ),
        ),
      );
      expect(NotificationNavigationPayload.tryParse(null), isNull);
      expect(NotificationNavigationPayload.tryParse('not-json'), isNull);
      expect(NotificationNavigationPayload.tryParse('["list"]'), isNull);
      expect(NotificationNavigationPayload.tryParse('{}'), isNull);
      expect(
        NotificationNavigationPayload.tryParse(
          '{"redirectUri":"https://evil.test"}',
        ),
        isNull,
      );
    });
  });

  group('NotificationNavigationCoordinator', () {
    test('handles select/action responses, ignores dismissals, and consumes once', () {
      final coordinator = NotificationNavigationCoordinator();

      expect(coordinator.handleNotificationResponse(null), isFalse);
      expect(
        coordinator.handleNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.notificationDismissed,
            payload: '{"redirectUri":"/common/conversations/home"}',
          ),
        ),
        isFalse,
      );
      expect(coordinator.pending, isNull);

      expect(
        coordinator.handleNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: const NotificationNavigationPayload(
              redirectUri: '/common/conversations/home',
              accountId: 2,
            ).encode(),
          ),
        ),
        isTrue,
      );

      // Retained when active account differs.
      expect(coordinator.takePending(activeAccountId: 1), isNull);
      expect(coordinator.pending, isNotNull);

      // Replaced by newer tap.
      expect(
        coordinator.handleNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            payload: const NotificationNavigationPayload(
              redirectUri: '/common/substitutions/home',
              accountId: 2,
            ).encode(),
          ),
        ),
        isTrue,
      );

      final consumed = coordinator.takePending(activeAccountId: 2);
      expect(consumed?.redirectUri, '/common/substitutions/home');
      expect(coordinator.pending, isNull);
      expect(coordinator.takePending(activeAccountId: 2), isNull);
    });
  });

  group('conversationChatPath', () {
    test('encodes id and title and handles empty title', () {
      expect(
        conversationChatPath(id: 'a/b 1', title: 'Hello World & More'),
        '/common/conversations/chat/a%2Fb%201?title=Hello%20World%20%26%20More',
      );
      expect(
        conversationChatPath(id: '42', title: ''),
        '/common/conversations/chat/42',
      );
    });
  });

  group('BackgroundTaskToolkit.sendMessage payload', () {
    test('sends explicit redirectUri and falls back to defaultRedirectUri', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();

      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(flnChannel, (call) async {
            calls.add(call);
            return null;
          });

      final db = LanisDatabase.open();
      addTearDown(db.dispose);
      final toolkit = BackgroundTaskToolkit(
        accountId: 3,
        username: 'user',
        schoolName: 'School',
        settings: TypedSettings.account(db, 3),
        appletId: 'nachrichten.php',
        defaultRedirectUri: '/common/conversations/home',
      );

      await toolkit.sendMessage(
        title: 'Chat',
        message: 'Body',
        id: 10,
        redirectUri: '/common/conversations/chat/42?title=Hi',
      );
      await toolkit.sendMessage(
        title: 'Default',
        message: 'Fallback',
        id: 11,
      );

      expect(calls, hasLength(2));
      final firstArgs = Map<String, dynamic>.from(calls[0].arguments as Map);
      final secondArgs = Map<String, dynamic>.from(calls[1].arguments as Map);

      expect(
        jsonDecode(firstArgs['payload'] as String),
        equals({
          'redirectUri': '/common/conversations/chat/42?title=Hi',
          'accountId': 3,
        }),
      );
      expect(
        jsonDecode(secondArgs['payload'] as String),
        equals({
          'redirectUri': '/common/conversations/home',
          'accountId': 3,
        }),
      );
    });
  });

  group('End-to-end router + auth + NotificationNavigationDriver', () {
    testWidgets('cold start single account lands directly on chat detail', (
      tester,
    ) async {
      installFakeSessionAuth();
      final coordinator = NotificationNavigationCoordinator();
      final container = await _createNotificationTestContainer(
        coordinator: coordinator,
      );
      addTearDown(container.dispose);

      acceptPrivacy(container);
      final id = await addTestAccount(container);
      coordinator.handlePayload(
        NotificationNavigationPayload(
          redirectUri: conversationChatPath(id: '42', title: 'Hello'),
          accountId: id,
        ).encode(),
      );

      await _pumpRouterApp(tester, container);
      await _settle(tester);

      final router = container.read(goRouterProvider);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/common/conversations/chat/42?title=Hello',
      );
      expect(find.byType(ConversationsChat), findsOneWidget);
      expect(coordinator.pending, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('warm start same account navigates from substitutions to conversations', (
      tester,
    ) async {
      installFakeSessionAuth();
      final coordinator = NotificationNavigationCoordinator();
      final container = await _createNotificationTestContainer(
        coordinator: coordinator,
      );
      addTearDown(container.dispose);

      acceptPrivacy(container);
      final id = await addTestAccount(container);

      await _pumpRouterApp(tester, container);
      await _settle(tester);

      final router = container.read(goRouterProvider);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/common/substitutions/home',
      );
      expect(find.byType(SubstitutionsView), findsOneWidget);

      coordinator.handleNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: NotificationNavigationPayload(
            redirectUri: conversationsHomePath,
            accountId: id,
          ).encode(),
        ),
      );
      await _settle(tester);

      expect(
        router.routeInformationProvider.value.uri.path,
        '/common/conversations/home',
      );
      expect(find.byType(ConversationsView), findsOneWidget);
      expect(coordinator.pending, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('cold start multi-account selects notification target account', (
      tester,
    ) async {
      installFakeSessionAuth();
      final coordinator = NotificationNavigationCoordinator();
      final container = await _createNotificationTestContainer(
        coordinator: coordinator,
      );
      addTearDown(container.dispose);

      acceptPrivacy(container);
      final idA = await addTestAccount(container, username: 'alpha');
      final idB = await addTestAccount(
        container,
        schoolId: 2,
        username: 'beta',
      );
      await container.read(lanisDatabaseProvider).updateLastLogin(idA);

      coordinator.handlePayload(
        NotificationNavigationPayload(
          redirectUri: conversationsHomePath,
          accountId: idB,
        ).encode(),
      );

      await _pumpRouterApp(tester, container);
      await _settle(tester);

      expect(container.read(activeAccountProvider)?.localId, idB);
      expect(
        container.read(goRouterProvider).routeInformationProvider.value.uri.path,
        '/common/conversations/home',
      );
      expect(coordinator.pending, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('warm start multi-account switches account and navigates', (
      tester,
    ) async {
      installFakeSessionAuth();
      final coordinator = NotificationNavigationCoordinator();
      final container = await _createNotificationTestContainer(
        coordinator: coordinator,
      );
      addTearDown(container.dispose);

      acceptPrivacy(container);
      final idA = await addTestAccount(container, username: 'alpha');
      final idB = await addTestAccount(
        container,
        schoolId: 2,
        username: 'beta',
      );
      await container.read(lanisDatabaseProvider).updateLastLogin(idA);

      await _pumpRouterApp(tester, container);
      await _settle(tester);
      expect(container.read(activeAccountProvider)?.localId, idA);

      coordinator.handlePayload(
        NotificationNavigationPayload(
          redirectUri: conversationsHomePath,
          accountId: idB,
        ).encode(),
      );
      await _settle(tester);

      expect(container.read(activeAccountProvider)?.localId, idB);
      expect(
        container.read(goRouterProvider).routeInformationProvider.value.uri.path,
        '/common/conversations/home',
      );
      expect(coordinator.pending, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('missing account clears pending and keeps active account', (
      tester,
    ) async {
      installFakeSessionAuth();
      final coordinator = NotificationNavigationCoordinator();
      final container = await _createNotificationTestContainer(
        coordinator: coordinator,
      );
      addTearDown(container.dispose);

      acceptPrivacy(container);
      final idA = await addTestAccount(container, username: 'alpha');

      await _pumpRouterApp(tester, container);
      await _settle(tester);
      expect(container.read(activeAccountProvider)?.localId, idA);

      coordinator.handlePayload(
        const NotificationNavigationPayload(
          redirectUri: conversationsHomePath,
          accountId: 999,
        ).encode(),
      );
      await _settle(tester);

      expect(container.read(activeAccountProvider)?.localId, idA);
      expect(coordinator.pending, isNull);
      expect(
        container.read(goRouterProvider).routeInformationProvider.value.uri.path,
        '/common/substitutions/home',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('unsupported route for account opens deep-link error without loop', (
      tester,
    ) async {
      installFakeSessionAuth();
      final coordinator = NotificationNavigationCoordinator();
      final container = await _createNotificationTestContainer(
        coordinator: coordinator,
      );
      addTearDown(container.dispose);

      acceptPrivacy(container);
      final id = await addTestAccount(
        container,
        accountType: AccountType.student,
      );

      await _pumpRouterApp(tester, container);
      await _settle(tester);

      coordinator.handlePayload(
        NotificationNavigationPayload(
          redirectUri: '/teacher/lessons/home',
          accountId: id,
        ).encode(),
      );
      await _settle(tester);

      expect(
        container.read(goRouterProvider).routeInformationProvider.value.uri.path,
        SettingsDeepLinks.deepLinkError,
      );
      expect(find.byType(DeepLinkErrorPage), findsOneWidget);
      expect(coordinator.pending, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('logout clears pending notification target', (tester) async {
      installFakeSessionAuth();
      final coordinator = NotificationNavigationCoordinator();
      final container = await _createNotificationTestContainer(
        coordinator: coordinator,
      );
      addTearDown(container.dispose);

      acceptPrivacy(container);
      final id = await addTestAccount(container);

      await _pumpRouterApp(tester, container);
      await _settle(tester);

      await container.read(authControllerProvider.notifier).logout();
      await _settle(tester);

      coordinator.handlePayload(
        NotificationNavigationPayload(
          redirectUri: conversationsHomePath,
          accountId: id,
        ).encode(),
      );
      await _settle(tester);

      expect(coordinator.pending, isNull);
      expect(
        container.read(goRouterProvider).routeInformationProvider.value.uri.path,
        '/welcome',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'cold start preserves redirectUri when accountsProvider invalidates during auth',
      (tester) async {
        installFakeSessionAuth();
        AuthController.debugAuthenticate = (ref) async {
          ref.invalidate(accountsProvider);
        };
        addTearDown(() => AuthController.debugAuthenticate = null);

        final coordinator = NotificationNavigationCoordinator();
        final container = await _createNotificationTestContainer(
          coordinator: coordinator,
        );
        addTearDown(container.dispose);

        acceptPrivacy(container);
        final id = await addTestAccount(container);
        coordinator.handlePayload(
          NotificationNavigationPayload(
            redirectUri: conversationsHomePath,
            accountId: id,
          ).encode(),
        );

        await _pumpRouterApp(tester, container);
        await _settle(tester);

        final router = container.read(goRouterProvider);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          conversationsHomePath,
        );
        expect(find.byType(ConversationsView), findsOneWidget);
        expect(coordinator.pending, isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('NotificationNavigationCoordinator dispatch idempotency', () {
    test('peekPending and markDispatched stay idempotent until committed', () {
      final coordinator = NotificationNavigationCoordinator();
      coordinator.handlePayload(
        const NotificationNavigationPayload(
          redirectUri: '/common/conversations/home',
          accountId: 1,
        ).encode(),
      );

      final first = coordinator.peekPending(activeAccountId: 1);
      expect(first?.redirectUri, '/common/conversations/home');
      coordinator.markDispatched(first!);

      // Second redirect check before route commit must still see the target.
      final second = coordinator.peekPending(activeAccountId: 1);
      expect(second?.redirectUri, '/common/conversations/home');
      expect(identical(first, second), isTrue);

      // Replacing pending with a newer notification resets dispatched state.
      coordinator.handlePayload(
        const NotificationNavigationPayload(
          redirectUri: '/common/substitutions/home',
          accountId: 1,
        ).encode(),
      );
      expect(coordinator.clearIfDispatched(), isFalse);
      expect(coordinator.pending?.redirectUri, '/common/substitutions/home');

      final latest = coordinator.peekPending(activeAccountId: 1)!;
      coordinator.markDispatched(latest);
      expect(coordinator.clearIfDispatched(), isTrue);
      expect(coordinator.pending, isNull);
    });
  });
}
