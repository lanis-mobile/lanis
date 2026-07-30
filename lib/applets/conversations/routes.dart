import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/conversations/conversations_nav.dart';
import 'package:lanis/applets/conversations/view/chat.dart';
import 'package:lanis/applets/conversations/view/components/statistic_widget.dart';
import 'package:lanis/applets/conversations/view/conversations_view.dart';
import 'package:lanis/applets/conversations/view/new_conversation_configurator.dart';
import 'package:lanis/applets/conversations/view/send.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/conversations/definition.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/widgets/applet_home_shell.dart';
import 'package:lanis/widgets/error_view.dart';
import 'package:liblanis/liblanis.dart';

List<RouteBase> buildConversationsRoutes(AppletRouteContext ctx) {
  final home = conversationsDefinition.homePath();
  return [
    GoRoute(
      path: '/common/conversations',
      redirect: (context, state) {
        if (state.uri.path == '/common/conversations') return home;
        return null;
      },
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            if (Responsive.isSplitView(context)) {
              return ConversationsTabletShell(child: child);
            }
            return child;
          },
          routes: [
            appletHomeShell(
              homeBuilder: (context, state) {
                if (Responsive.isSplitView(context)) {
                  return const SizedBox.shrink();
                }
                return ctx.homeBody(conversationsDefinition);
              },
            ),
            GoRoute(
              path: 'compose',
              builder: (context, state) => DeepLinkPopScope(
                fallbackPath: home,
                child: ConversationComposePage(
                  subject: state.uri.queryParameters['subject'],
                  typeName: state.uri.queryParameters['type'],
                  receivers: state.uri.queryParameters['receivers']
                      ?.split(',')
                      .where((e) => e.isNotEmpty)
                      .toList(),
                ),
              ),
            ),
            GoRoute(
              path: 'chat/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                final title = state.uri.queryParameters['title'] ?? '';
                final extra = state.extra;
                return DeepLinkPopScope(
                  fallbackPath: home,
                  child: ConversationChatPage(
                    id: id,
                    title: title,
                    newSettings: extra is NewConversationSettings ? extra : null,
                  ),
                );
              },
              routes: [
                GoRoute(
                  path: 'stats',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    final title = state.uri.queryParameters['title'] ?? '';
                    return DeepLinkPopScope(
                      fallbackPath: '/common/conversations/chat/$id',
                      child: ConversationStatsPage(id: id, title: title),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}

/// Tablet master–detail: conversation list beside the matched child route.
class ConversationsTabletShell extends StatelessWidget {
  final Widget child;

  const ConversationsTabletShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final onHome = loc == conversationsHomePath || loc == '/common/conversations';
    final deviceWidth = MediaQuery.sizeOf(context).width;
    final widthParts = deviceWidth ~/ 350 == 0 ? 1 : deviceWidth ~/ 350;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: widthParts >= 3 ? 1 : 4,
            child: const ConversationsView(embeddedInTabletShell: true),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outline,
          ),
          Expanded(
            flex: widthParts >= 3 ? 2 : 6,
            child: onHome
                ? const ConversationsEmptyDetail()
                : SizedBox.expand(child: child),
          ),
        ],
      ),
    );
  }
}

class ConversationsEmptyDetail extends StatelessWidget {
  const ConversationsEmptyDetail({super.key});

  @override
  Widget build(BuildContext context) {
    const assets = [
      'assets/undraw/chat/undraw_work-chat_hc3y.svg',
      'assets/undraw/chat/undraw_quick-chat_3gj8.svg',
      'assets/undraw/chat/undraw_online-message_k64b.svg',
      'assets/undraw/chat/undraw_chatting_5u5z.svg',
      'assets/undraw/chat/undraw_chat_qmyo.svg',
    ];
    final asset =
        assets[(DateTime.now().millisecondsSinceEpoch / 1000).toInt() %
            assets.length];
    return Center(child: SvgPicture.asset(asset, height: 175));
  }
}

class ConversationChatPage extends ConsumerWidget {
  final String id;
  final String title;
  final NewConversationSettings? newSettings;

  const ConversationChatPage({
    super.key,
    required this.id,
    required this.title,
    this.newSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConversationsChat(
      key: ValueKey(id),
      id: id,
      title: title,
      newSettings: newSettings,
      onSidebarChanged: () {
        ref.read(conversationsParserProvider).fetchData(forceRefresh: true);
      },
    );
  }
}

class ConversationComposePage extends ConsumerStatefulWidget {
  final String? subject;
  final String? typeName;
  final List<String>? receivers;

  const ConversationComposePage({
    super.key,
    this.subject,
    this.typeName,
    this.receivers,
  });

  @override
  ConsumerState<ConversationComposePage> createState() =>
      _ConversationComposePageState();
}

class _ConversationComposePageState
    extends ConsumerState<ConversationComposePage> {
  @override
  void initState() {
    super.initState();
    final hasPrefill =
        (widget.subject != null && widget.subject!.isNotEmpty) &&
        (widget.receivers != null && widget.receivers!.isNotEmpty);
    if (hasPrefill) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPrefill());
    }
  }

  Future<void> _openPrefill() async {
    final type = ChatType.values.cast<ChatType?>().firstWhere(
      (t) => t?.name == widget.typeName,
      orElse: () => null,
    );
    final data = ChatCreationData(
      type: type,
      subject: widget.subject!,
      receivers: widget.receivers!,
    );
    if (!mounted) return;
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) =>
            FullScreenConversationsMessageInput(creationData: data),
      ),
    );
    if (!mounted) return;
    if (text == null) {
      context.pop();
      return;
    }
    context.pop(ChatCreationData(
      type: data.type,
      subject: data.subject,
      receivers: data.receivers,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasPrefill =
        (widget.subject != null && widget.subject!.isNotEmpty) &&
        (widget.receivers != null && widget.receivers!.isNotEmpty);
    if (hasPrefill) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const NewConversationConfigurator();
  }
}

class ConversationStatsPage extends ConsumerStatefulWidget {
  final String id;
  final String title;

  const ConversationStatsPage({
    super.key,
    required this.id,
    required this.title,
  });

  @override
  ConsumerState<ConversationStatsPage> createState() =>
      _ConversationStatsPageState();
}

class _ConversationStatsPageState extends ConsumerState<ConversationStatsPage> {
  late final Future<Conversation> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(conversationsParserProvider)
        .getSingleConversation(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Conversation>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final err = snapshot.error;
          return Scaffold(
            appBar: AppBar(),
            body: AppletErrorView(
              error: err is Exception ? err : Exception(err.toString()),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final chat = snapshot.data!;
        return StatisticWidget(
          statistics: ParticipationStatistics(
            countParents: chat.countParents,
            countStudents: chat.countStudents,
            countTeachers: chat.countTeachers,
            knownParticipants: chat.knownParticipants,
          ),
          conversationTitle: widget.title.isNotEmpty
              ? widget.title
              : chat.parent.author,
        );
      },
    );
  }
}
