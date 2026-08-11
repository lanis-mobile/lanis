import 'package:flutter/material.dart';

class MarqueeWidget extends StatefulWidget {
  final Widget child;
  final Axis direction;
  final Duration animationDuration, backDuration, pauseDuration;

  const MarqueeWidget({
    super.key,
    required this.child,
    this.direction = Axis.horizontal,
    this.animationDuration = const Duration(milliseconds: 6000),
    this.backDuration = const Duration(milliseconds: 800),
    this.pauseDuration = const Duration(milliseconds: 800),
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> {
  late ScrollController scrollController;
  bool _active = true;

  @override
  void initState() {
    scrollController = ScrollController(initialScrollOffset: 50.0);
    WidgetsBinding.instance.addPostFrameCallback(scroll);
    super.initState();
  }

  @override
  void dispose() {
    _active = false;
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: widget.direction,
      controller: scrollController,
      child: Center(child: widget.child),
    );
  }

  void scroll(_) async {
    while (_active && scrollController.hasClients) {
      await Future.delayed(widget.pauseDuration);
      if (!_active || !scrollController.hasClients) return;
      await scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: widget.animationDuration,
        curve: Curves.ease,
      );
      if (!_active) return;
      await Future.delayed(widget.pauseDuration);
      if (!_active || !scrollController.hasClients) return;
      await scrollController.animateTo(
        0.0,
        duration: widget.backDuration,
        curve: Curves.easeOut,
      );
    }
  }
}
