import 'package:flutter/material.dart';

/// Small FAB that scrolls the reverse chat list back to the latest messages.
class ChatScrollToBottomFab extends StatelessWidget {
  final ValueNotifier<bool> isVisible;
  final VoidCallback onPressed;

  const ChatScrollToBottomFab({
    super.key,
    required this.isVisible,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isVisible,
      builder: (context, visible, _) {
        return Visibility(
          visible: visible,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 60),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: onPressed,
              child: Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondaryFixedDim,
                    width: 1.5,
                  ),
                  color: Theme.of(context).colorScheme.surfaceDim,
                ),
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
          ),
        );
      },
    );
  }
}
