import 'package:flutter/material.dart';

class ScrolledDownContainer extends StatefulWidget {
  final Widget child;

  const ScrolledDownContainer({super.key, required this.child});

  @override
  State<ScrolledDownContainer> createState() => _ScrolledDownContainerState();
}

class _ScrolledDownContainerState extends State<ScrolledDownContainer> {
  ScrollNotificationObserverState? scrollNotificationObserver;
  bool scrolledDown = false;

  void handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        defaultScrollNotificationPredicate(notification)) {
      final ScrollMetrics metrics = notification.metrics;
      if (scrolledDown != metrics.extentBefore > 0) {
        setState(() {
          scrolledDown = metrics.extentBefore > 0;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    scrollNotificationObserver?.removeListener(handleScrollNotification);
    scrollNotificationObserver = ScrollNotificationObserver.maybeOf(context);
    scrollNotificationObserver?.addListener(handleScrollNotification);
  }

  @override
  void dispose() {
    super.dispose();

    if (scrollNotificationObserver != null) {
      scrollNotificationObserver!.removeListener(handleScrollNotification);
      scrollNotificationObserver = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: widget.child,
    );
  }
}
