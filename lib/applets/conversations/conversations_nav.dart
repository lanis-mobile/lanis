import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:liblanis/liblanis.dart';

const conversationsHomePath = '/common/conversations/home';
const conversationsComposePath = '/common/conversations/compose';

/// Optional route `extra` payload for `/common/conversations/compose`.
class ConversationComposeExtra {
  final List<ReceiverEntry> initialReceivers;
  final String? initialSubject;

  /// When true, [ConversationComposePage] completes the full compose → message
  /// input → createConversation → open chat flow directly (e.g. when launched
  /// via deep-link from Study Groups or Lessons).
  final bool handleSubmission;

  const ConversationComposeExtra({
    this.initialReceivers = const [],
    this.initialSubject,
    this.handleSubmission = true,
  });
}

/// Canonical deep-link location for a conversation chat view.
String conversationChatPath({required String id, required String title}) {
  final encodedId = Uri.encodeComponent(id);
  if (title.isEmpty) {
    return '/common/conversations/chat/$encodedId';
  }
  final encodedTitle = Uri.encodeComponent(title);
  return '/common/conversations/chat/$encodedId?title=$encodedTitle';
}

/// Opens a conversation: [go] on tablet (detail pane), [push] (or
/// [pushReplacement] when [replace] is true) on phone.
void openConversationRoute(
  BuildContext context, {
  required String id,
  required String title,
  Object? extra,
  bool replace = false,
}) {
  final path = conversationChatPath(id: id, title: title);
  if (Responsive.isSplitView(context)) {
    context.go(path, extra: extra);
  } else if (replace) {
    context.pushReplacement(path, extra: extra);
  } else {
    context.push(path, extra: extra);
  }
}

/// Opens the Conversations compose flow with prefilled [receivers] (and
/// optional [subject]). Uses [go] on tablet split-view and [push] on phone.
void openComposeConversation(
  BuildContext context, {
  required List<ReceiverEntry> receivers,
  String? subject,
}) {
  final extra = ConversationComposeExtra(
    initialReceivers: receivers,
    initialSubject: subject,
    handleSubmission: true,
  );
  if (Responsive.isSplitView(context)) {
    context.go(conversationsComposePath, extra: extra);
  } else {
    context.push(conversationsComposePath, extra: extra);
  }
}

/// Creates a new conversation, refreshes the overview, and opens the chat.
///
/// Returns the created conversation ID on success, or `null` if offline or on
/// failure (after displaying the corresponding error dialog).
Future<String?> createAndOpenConversation(
  BuildContext context,
  WidgetRef ref, {
  required String text,
  required ChatCreationData creationData,
  bool replaceRoute = false,
  ValueChanged<String>? onCreated,
}) async {
  final bool status = await ref.read(connectionCheckerProvider).connected;
  if (!status) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(Icons.wifi_off),
            title: Text(AppLocalizations.of(dialogContext).noInternetConnection2),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Ok'),
              ),
            ],
          );
        },
      );
    }
    return null;
  }

  final textMessage = Message(
    text: text,
    own: true,
    date: DateTime.now(),
    author: null,
    state: MessageState.first,
    status: MessageStatus.sent,
  );

  final CreationResponse response;
  try {
    response = await ref
        .read(conversationsParserProvider)
        .createConversation(
          creationData.receivers,
          creationData.type?.name,
          creationData.subject,
          text,
        );
  } catch (_) {
    if (context.mounted) {
      await _showCreateErrorDialog(context);
    }
    return null;
  }

  if (response.success && response.id != null) {
    final createdId = response.id!;
    ref.read(conversationsParserProvider).fetchData(forceRefresh: true);
    onCreated?.call(createdId);

    if (context.mounted) {
      openConversationRoute(
        context,
        id: createdId,
        title: creationData.subject,
        replace: replaceRoute,
        extra: NewConversationSettings(
          firstMessage: textMessage,
          settings: ConversationSettings(
            id: createdId,
            groupChat: creationData.type == ChatType.groupOnly,
            onlyPrivateAnswers:
                creationData.type == ChatType.privateAnswerOnly,
            noReply: creationData.type == ChatType.noAnswerAllowed,
            own: true,
          ),
        ),
      );
    }
    return createdId;
  }

  if (context.mounted) {
    await _showCreateErrorDialog(context);
  }
  return null;
}

Future<void> _showCreateErrorDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: const Icon(Icons.error),
        title: Text(
          AppLocalizations.of(dialogContext).errorCreatingConversation,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ok'),
          ),
        ],
      );
    },
  );
}

/// Chat id from the current location, if on a chat (or stats) route.
String? conversationIdFromLocation(String path) {
  final match = RegExp(r'/common/conversations/chat/([^/]+)').firstMatch(path);
  return match?.group(1);
}
