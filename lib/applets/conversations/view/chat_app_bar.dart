import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/conversations/conversations_nav.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:liblanis/liblanis.dart';

/// App bar for an open conversation, including refresh/status actions.
class ConversationsChatAppBar extends StatelessWidget {
  final String title;
  final bool refreshing;
  final ConversationSettings settings;
  final ParticipationStatistics? statistics;
  final String conversationId;

  const ConversationsChatAppBar({
    super.key,
    required this.title,
    required this.refreshing,
    required this.settings,
    required this.statistics,
    required this.conversationId,
  });

  void _leaveChat(BuildContext context) {
    // Tablet opens chat via go_router.go, so there is often nothing to pop.
    // Prefer the local navigator; otherwise return to the list home.
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.go(conversationsHomePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read live — route builders may not rebuild across phone/tablet resize.
    final showBack = !Responsive.isConversationsSplit(context);
    return AppBar(
      title: Text(title),
      scrolledUnderElevation: 0.0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: showBack
          ? BackButton(onPressed: () => _leaveChat(context))
          : null,
      actions: [
        if (refreshing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        if (settings.groupChat == false &&
            settings.onlyPrivateAnswers == false &&
            settings.noReply == false)
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    icon: const Icon(Icons.groups),
                    title: Text(
                      AppLocalizations.of(
                        context,
                      ).conversationTypeName(ChatType.openChat.name),
                    ),
                    content: Text(AppLocalizations.of(context).openChatWarning),
                    actions: [
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text("Ok"),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.warning),
          ),
        if (statistics != null)
          IconButton(
            onPressed: () {
              final encoded = Uri.encodeComponent(title);
              context.push(
                '/common/conversations/chat/$conversationId/stats?title=$encoded',
              );
            },
            icon: const Icon(Icons.people),
          ),
      ],
    );
  }
}
