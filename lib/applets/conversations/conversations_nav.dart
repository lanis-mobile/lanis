import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/utils/responsive.dart';

const conversationsHomePath = '/common/conversations/home';

/// Opens a conversation: [go] on tablet (detail pane), [push] on phone.
void openConversationRoute(
  BuildContext context, {
  required String id,
  required String title,
  Object? extra,
}) {
  final encoded = Uri.encodeComponent(title);
  final path = '/common/conversations/chat/$id?title=$encoded';
  if (Responsive.isConversationsSplit(context)) {
    context.go(path, extra: extra);
  } else {
    context.push(path, extra: extra);
  }
}

/// Chat id from the current location, if on a chat (or stats) route.
String? conversationIdFromLocation(String path) {
  final match = RegExp(r'/common/conversations/chat/([^/]+)').firstMatch(path);
  return match?.group(1);
}
