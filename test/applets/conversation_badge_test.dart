import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/conversations/conversation_badge.dart';

void main() {
  test('shows badge when unread and not suppressed', () {
    expect(
      conversationShowsUnreadBadge(
        unread: true,
        entryId: 'a',
        loadedConversationId: null,
        noBadgeConversations: const [],
      ),
      isTrue,
    );
  });

  test('hides when not unread', () {
    expect(
      conversationShowsUnreadBadge(
        unread: false,
        entryId: 'a',
        loadedConversationId: null,
        noBadgeConversations: const [],
      ),
      isFalse,
    );
  });

  test('hides when conversation is currently loaded/open', () {
    expect(
      conversationShowsUnreadBadge(
        unread: true,
        entryId: 'a',
        loadedConversationId: 'a',
        noBadgeConversations: const [],
      ),
      isFalse,
    );
  });

  test('hides when id is in noBadgeConversations', () {
    expect(
      conversationShowsUnreadBadge(
        unread: true,
        entryId: 'a',
        loadedConversationId: null,
        noBadgeConversations: const ['a'],
      ),
      isFalse,
    );
  });

  test('still shows other unread entries when one is suppressed', () {
    expect(
      conversationShowsUnreadBadge(
        unread: true,
        entryId: 'b',
        loadedConversationId: 'a',
        noBadgeConversations: const ['a'],
      ),
      isTrue,
    );
  });
}
