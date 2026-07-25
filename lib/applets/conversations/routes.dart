import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/conversations/view/chat.dart';
import 'package:lanis/applets/conversations/view/components/statistic_widget.dart';
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
        appletHomeShell(
          homeBuilder: (context, state) =>
              ctx.homeBody(conversationsDefinition),
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
            return DeepLinkPopScope(
              fallbackPath: home,
              child: ConversationChatPage(id: id, title: title),
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
  ];
}

class ConversationChatPage extends ConsumerWidget {
  final String id;
  final String title;

  const ConversationChatPage({
    super.key,
    required this.id,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConversationsChat(
      id: id,
      title: title,
      isTablet: Responsive.isTablet(context),
      refreshSidebar: () {},
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
    // Caller (ConversationsView) handles creation when using push; for deep
    // links we create here.
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
