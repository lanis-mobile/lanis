import 'package:flutter/material.dart';
import 'package:lanis/applets/conversations/view/conversations_view.dart';
import 'package:lanis/core/sph/sph.dart';
import 'package:lanis/models/conversations.dart';

class ConversationTile extends StatelessWidget {
  final OverviewEntry entry;
  final bool toggleMode;
  final bool checked;
  final Function(OverviewEntry) onTap;
  final bool isOpen;
  final String? loadedConversationId;
  final List<String> noBadgeConversations;

  const ConversationTile(
      {super.key,
      required this.entry,
      required this.toggleMode,
      required this.checked,
      required this.onTap,
      required this.isOpen,
      required this.loadedConversationId,
      required this.noBadgeConversations});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        margin: const EdgeInsets.all(0),
        color: entry.hidden
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerLow
                .withValues(alpha: 0.8)
            : null,
        child: Stack(
          children: [
            if (isOpen) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 40,
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(8.0)),
                  )
                ],
              )
            ],
            Stack(
              alignment: Alignment.center,
              children: [
                if (entry.hidden) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 64.0),
                        child: Icon(
                          Icons.visibility_off,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.05)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow
                                  .withValues(alpha: 0.8),
                          size: 65,
                        ),
                      ),
                    ],
                  ),
                ],
                Badge(
                  smallSize:
                      (entry.unread && entry.id != loadedConversationId ||
                              noBadgeConversations.contains(entry.id))
                          ? 9
                          : 0,
                  child: InkWell(
                    onTap: () {
                      if (toggleMode) {
                        CheckTileNotification(id: entry.id).dispatch(context);
                        return;
                      }
                      onTap(entry);
                    },
                    onLongPress: () async {
                      // Try to let the tile be in same place as in the old list.
                      if (!toggleMode) {
                        final List<OverviewEntry> oldEntries = sph!
                            .parser.conversationsParser.stream.value.content!;
                        final oldPosition =
                            oldEntries.indexOf(entry) * tileSize;

                        CheckTileNotification(id: entry.id).dispatch(context);

                        final List<OverviewEntry> entries = sph!
                            .parser.conversationsParser.stream.value.content!;

                        final index = entries.indexOf(entry);
                        final position = index * tileSize;
                        final offset =
                            Scrollable.of(context).deltaToScrollOrigin.dy;

                        final newOffset = position + (offset - oldPosition);
                        JumpToNotification(position: newOffset)
                            .dispatch(context);
                      }
                    },
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Visibility(
                            visible: toggleMode,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Icon(
                                checked
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )),
                        Expanded(
                          child: ListTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  flex: 3,
                                  child: Text(
                                    entry.title,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                                if (entry.shortName != null) ...[
                                  Flexible(
                                    child: Text(
                                      entry.shortName!,
                                      overflow: TextOverflow.ellipsis,
                                      style: entry.shortName != null
                                          ? Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                          : Theme.of(context)
                                              .textTheme
                                              .titleMedium!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                            subtitle: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.date,
                                ),
                                Text(
                                  entry.fullName,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
