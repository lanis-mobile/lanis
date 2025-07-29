import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/widgets/format_text.dart';

class MessageWidget extends StatelessWidget {
  final Message message;
  final TextStyle? textStyle;

  const MessageWidget(
      {super.key, required this.message, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    final double size = MediaQuery.sizeOf(context).width - 200;

    return Padding(
      padding: BubbleStructure.getMargin(message.state),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: BubbleStructure.getAlignment(message.own),
        children: [
          // Author name
          if (message.state == MessageState.first && !message.own) ...[
            Text(
              message.author!,
              style: textStyle,
            )
          ],

          // Message bubble
          ClipPath(
            clipper: message.state == MessageState.first
                ? BubbleStructure.getFirstStateClipper(message.own)
                : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.clamp(350, 600),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BubbleStyles.getStyle(message.own).mainColor,
                  borderRadius: message.state != MessageState.first
                      ? BubbleStructure.radius
                      : null,
                ),
                child: Padding(
                  padding: BubbleStructure.getPadding(
                      message.state == MessageState.first, message.own),
                  child: FormattedText(
                      text: message.text,
                      formatStyle:
                          BubbleStyles.getStyle(message.own).textFormatStyle),
                ),
              ),
            ),
          ),

          // Date text
          Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: message.state == MessageState.first
                      ? BubbleStructure.compensatedPadding
                      : BubbleStructure.horizontalPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat("HH:mm").format(message.date),
                      style: BubbleStyles.getStyle(message.own).dateTextStyle),
                  if (message.own) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Icon(
                        Icons.circle,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 3,
                      ),
                    ),
                    if (message.status == MessageStatus.sending) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 2.0),
                        child: SizedBox(
                            width: 10.0,
                            height: 10.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                            )),
                      )
                    ] else if (message.status == MessageStatus.error) ...[
                      Icon(
                        Icons.error,
                        color: Theme.of(context).colorScheme.error,
                        size: 12,
                      )
                    ] else ...[
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 12,
                      )
                    ]
                  ]
                ],
              ))
        ],
      ),
    );
  }
}
