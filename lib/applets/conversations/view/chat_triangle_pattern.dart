import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Full-bleed triangle background used behind the conversation message list.
///
/// Fills the parent, then scales the square SVG with [BoxFit.cover] so the
/// pattern covers the whole area without changing its aspect ratio.
class ChatTrianglePattern extends StatelessWidget {
  final Color lineColor;

  const ChatTrianglePattern({super.key, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: SvgPicture.asset(
        "assets/triangle_pattern.svg",
        fit: BoxFit.cover,
        alignment: Alignment.center,
        colorFilter: ColorFilter.mode(lineColor, BlendMode.srcIn),
      ),
    );
  }
}
