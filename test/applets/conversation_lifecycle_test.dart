import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/conversations/routes.dart';
import 'package:lanis/applets/conversations/view/chat.dart';
import 'package:lanis/applets/conversations/view/conversations_view.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

class _OnlineChecker extends ConnectionChecker {
  @override
  Future<bool> testConnection() async => true;
}

class _Parser extends ConversationsParser {
  int refreshes = 0;
  final conversation = Completer<Conversation>();
  _Parser(super.ctx) {
    cachedCanChooseType = false;
  }

  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    refreshes++;
  }

  @override
  Future<Conversation> getSingleConversation(String uniqueID) =>
      conversation.future;
}

void main() {
  late _Parser parser;
  late LanisSession session;
  late LanisDatabase database;

  setUp(() {
    database = LanisDatabase.open();
    final account = ClearTextAccount(
      localId: 1,
      schoolID: 1,
      username: 'u',
      password: 'p',
      schoolName: 'Test',
    );
    session = LanisSession(
      account: account,
      config: const LanisConfig(),
      connectionChecker: _OnlineChecker(),
    );
    parser = _Parser(
      AppletContext(
        session: session,
        database: database,
        account: account,
        accountSettings: TypedSettings.account(database, 1),
      ),
    );
  });
  tearDown(() async {
    parser.dispose();
    await session.dispose();
    session.connectionChecker.dispose();
    database.dispose();
    LanisClient.reset();
  });

  for (final unmount in [true, false]) {
    testWidgets(
      'sidebar callback ${unmount ? 'after disposal is harmless' : 'still refreshes while mounted'}',
      (tester) async {
        await pumpTestApp(
          tester,
          child: const ConversationChatPage(id: 'test', title: 'Test'),
          overrides: [conversationsParserProvider.overrideWithValue(parser)],
        );
        final callback = tester
            .widget<ConversationsChat>(find.byType(ConversationsChat))
            .onSidebarChanged!;
        final before = parser.refreshes;
        if (unmount) await tester.pumpWidget(const SizedBox.shrink());
        callback();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(parser.refreshes, before + (unmount ? 0 : 1));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('disposed chat still refreshes its live overview', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await pumpTestApp(
      tester,
      child: ValueListenableBuilder(
        valueListenable: visible,
        builder: (_, show, _) => show
            ? const ConversationChatPage(id: 'test', title: 'Test')
            : const SizedBox.shrink(),
      ),
      overrides: [conversationsParserProvider.overrideWithValue(parser)],
    );
    final callback = tester
        .widget<ConversationsChat>(find.byType(ConversationsChat))
        .onSidebarChanged!;
    final before = parser.refreshes;
    visible.value = false;
    await tester.pump();
    expect(find.byType(ConversationChatPage), findsNothing);

    // sendMessage invokes this callback after its pending reply completes,
    // even when navigation has already removed the originating chat page.
    callback();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(parser.refreshes, before + 1);

    await tester.pumpWidget(const SizedBox.shrink());
    callback();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(parser.refreshes, before + 1);
  });

  testWidgets('late sidebar callback does not refresh a replaced parser', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final replacement = _Parser(parser.ctx);
    addTearDown(replacement.dispose);
    var currentParser = parser;
    final currentParserProvider = Provider<ConversationsParser>(
      (_) => currentParser,
    );
    final container = await pumpTestApp(
      tester,
      child: ValueListenableBuilder(
        valueListenable: visible,
        builder: (_, show, _) => show
            ? const ConversationChatPage(id: 'test', title: 'Test')
            : const SizedBox.shrink(),
      ),
      overrides: [
        conversationsParserProvider.overrideWith(
          (ref) => ref.watch(currentParserProvider),
        ),
      ],
    );
    final callback = tester
        .widget<ConversationsChat>(find.byType(ConversationsChat))
        .onSidebarChanged!;
    visible.value = false;
    await tester.pump();
    final before = parser.refreshes;
    currentParser = replacement;
    container.invalidate(currentParserProvider);
    // Invoke before pumping to cover invalidation awaiting a lazy rebuild.
    callback();
    await tester.pump();
    expect(container.read(conversationsParserProvider), same(replacement));
    expect(tester.takeException(), isNull);
    expect(parser.refreshes, before);
    expect(replacement.refreshes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mounted chat uses its replacement parser callback', (
    tester,
  ) async {
    final replacement = _Parser(parser.ctx);
    addTearDown(replacement.dispose);
    var currentParser = parser;
    final currentParserProvider = Provider<ConversationsParser>(
      (_) => currentParser,
    );
    final container = await pumpTestApp(
      tester,
      child: const ConversationChatPage(id: 'test', title: 'Test'),
      overrides: [
        conversationsParserProvider.overrideWith(
          (ref) => ref.watch(currentParserProvider),
        ),
      ],
    );
    final oldCallback = tester
        .widget<ConversationsChat>(find.byType(ConversationsChat))
        .onSidebarChanged!;
    final before = parser.refreshes;
    currentParser = replacement;
    container.invalidate(currentParserProvider);
    await tester.pump();
    oldCallback();
    final callback = tester
        .widget<ConversationsChat>(find.byType(ConversationsChat))
        .onSidebarChanged!;
    callback();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(parser.refreshes, before);
    expect(replacement.refreshes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late sidebar callback skips an unavailable parser', (tester) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    var unavailable = false;
    final currentParserProvider = Provider<ConversationsParser>((_) {
      if (unavailable) throw ConfigurationException('No active account');
      return parser;
    });
    final container = await pumpTestApp(
      tester,
      child: ValueListenableBuilder(
        valueListenable: visible,
        builder: (_, show, _) => show
            ? const ConversationChatPage(id: 'test', title: 'Test')
            : const SizedBox.shrink(),
      ),
      overrides: [
        conversationsParserProvider.overrideWith(
          (ref) => ref.watch(currentParserProvider),
        ),
      ],
    );
    final callback = tester
        .widget<ConversationsChat>(find.byType(ConversationsChat))
        .onSidebarChanged!;
    visible.value = false;
    await tester.pump();
    final before = parser.refreshes;
    unavailable = true;
    container.invalidate(currentParserProvider);
    // Logout can remove the active session before this pending reply finishes.
    expect(callback, returnsNormally);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(parser.refreshes, before);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('compose result after origin disposal does not navigate again', (
    tester,
  ) async {
    final showOrigin = ValueNotifier(true);
    addTearDown(showOrigin.dispose);
    await pumpTestRouterApp(
      tester,
      initialLocation: '/',
      overrides: [conversationsParserProvider.overrideWithValue(parser)],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder(
            valueListenable: showOrigin,
            builder: (_, visible, _) =>
                visible ? const ConversationsView() : const SizedBox.shrink(),
          ),
        ),
        GoRoute(
          path: '/common/conversations/compose',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(
                ChatCreationData(
                  type: ChatType.openChat,
                  subject: 'Test',
                  receivers: ['test'],
                ),
              ),
              child: const Text('Finish compose'),
            ),
          ),
        ),
      ],
    );
    final dynamic origin = tester.state(find.byType(ConversationsView));
    origin.openCreateConversation();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Finish compose'), findsOneWidget);
    showOrigin.value = false;
    await tester.pump();
    expect(origin.mounted, isFalse);
    await tester.tap(find.text('Finish compose'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scroll anchoring skips a list with no attached position', (
    tester,
  ) async {
    await pumpTestRouterApp(
      tester,
      initialLocation: '/',
      overrides: [conversationsParserProvider.overrideWithValue(parser)],
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ConversationsView()),
      ],
    );
    final dynamic page = tester.state(find.byType(ConversationsView));
    const entry = OverviewEntry(
      id: 'test',
      title: 'Test',
      shortName: null,
      fullName: 'Test',
      date: '1.1.2026',
      unread: false,
      hidden: false,
    );
    expect((page.scrollController as ScrollController).hasClients, isFalse);
    page.jumpToTopTile([entry], [entry]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('scroll anchoring still follows a reordered attached list', (
    tester,
  ) async {
    final attachedController = ValueNotifier<ScrollController?>(null);
    addTearDown(attachedController.dispose);
    await pumpTestRouterApp(
      tester,
      initialLocation: '/',
      overrides: [conversationsParserProvider.overrideWithValue(parser)],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Column(
            children: [
              const Expanded(child: ConversationsView()),
              SizedBox(
                height: 100,
                child: ValueListenableBuilder(
                  valueListenable: attachedController,
                  builder: (_, controller, _) => ListView(
                    controller: controller,
                    children: List.generate(
                      20,
                      (_) => const SizedBox(height: 80),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final dynamic page = tester.state(find.byType(ConversationsView));
    final controller = page.scrollController as ScrollController;
    attachedController.value = controller;
    await tester.pump();
    controller.jumpTo(40);
    final original = List.generate(
      10,
      (index) => OverviewEntry(
        id: '$index',
        title: 'Test',
        shortName: null,
        fullName: 'Test',
        date: '1.1.2026',
        unread: false,
        hidden: false,
      ),
    );
    final reordered = [
      original[1],
      original[2],
      original[0],
      ...original.skip(3),
    ];
    page.jumpToTopTile(reordered, original);
    expect(controller.offset, 200);
    expect(tester.takeException(), isNull);
  });
}
