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

    final shadow = BoxShadow(
      blurRadius: 2,
      blurStyle: BlurStyle.outer,
      color: Theme.of(context).colorScheme.shadow.withAlpha(45),
    );

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
          ClipShadowPath(
            clipper: message.state == MessageState.first
                ? BubbleStructure.getFirstStateClipper(message.own)
                : null,
            shadow: shadow,
            child: ClipPath(
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

@immutable
class ClipShadowPath extends StatelessWidget {
  final Shadow shadow;
  final CustomClipper<Path>? clipper;
  final Widget child;

  const ClipShadowPath({
    super.key,
    required this.shadow,
    required this.clipper,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (clipper != null) {
      return CustomPaint(
        key: UniqueKey(),
        painter: _ClipShadowShadowPainter(
          clipper: clipper!,
          shadow: shadow,
        ),
        child: ClipPath(clipper: clipper, child: child),
      );
    } else {
      // No clipper: just paint shadow as a rectangle behind the child
      return CustomPaint(
        key: UniqueKey(),
        painter: _RectShadowPainter(shadow: shadow),
        child: child,
      );
    }
  }
}

class _ClipShadowShadowPainter extends CustomPainter {
  final Shadow shadow;
  final CustomClipper<Path> clipper;

  _ClipShadowShadowPainter({required this.shadow, required this.clipper});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = shadow.toPaint();
    var clipPath = clipper.getClip(size).shift(shadow.offset);
    canvas.drawPath(clipPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class _RectShadowPainter extends CustomPainter {
  final Shadow shadow;

  _RectShadowPainter({required this.shadow});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = shadow.toPaint();
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.shift(shadow.offset),
      const Radius.circular(20), // You can adjust the radius as needed
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
