import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Full-bleed triangle background used behind the conversation message list.
class ChatTrianglePattern extends StatelessWidget {
  final Color lineColor;

  const ChatTrianglePattern({super.key, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      "assets/triangle_pattern.svg",
      fit: BoxFit.cover,
      colorFilter: ColorFilter.mode(lineColor, BlendMode.srcIn),
    );
  }
}
