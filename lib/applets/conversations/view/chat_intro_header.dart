import 'package:flutter/material.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/generated/l10n.dart';

/// Title (and optional private-conversation banner) shown above the oldest
/// message in the reverse chat list.
class ChatIntroHeader extends StatelessWidget {
  final String title;
  final ConversationSettings settings;

  const ChatIntroHeader({
    super.key,
    required this.title,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          if (settings.onlyPrivateAnswers && !settings.own) ...[
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 12.0,
              ),
              margin: const EdgeInsets.only(top: 16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              child: Text(
                AppLocalizations.of(
                  context,
                ).privateConversation(settings.author!),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
