/// Whether a conversation list tile should show the unread badge.
bool conversationShowsUnreadBadge({
  required bool unread,
  required String entryId,
  required String? loadedConversationId,
  required List<String> noBadgeConversations,
}) {
  return unread &&
      entryId != loadedConversationId &&
      !noBadgeConversations.contains(entryId);
}
