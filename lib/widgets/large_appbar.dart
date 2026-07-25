import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LargeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Color? backgroundColor;
  final Text title;
  final void Function()? back;
  final bool showBackButton;

  /// Used when the local navigator cannot pop (e.g. detail opened via
  /// [GoRouter.go] on tablet, then resized to phone).
  final String? fallbackLocation;

  const LargeAppBar({
    super.key,
    required this.title,
    this.backgroundColor,
    this.back,
    this.showBackButton = true,
    this.fallbackLocation,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (showBackButton ? 88 : 0));

  void _handleBack(BuildContext context) {
    if (back != null) {
      back!();
      return;
    }
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final fallback = fallbackLocation;
    if (fallback != null) {
      context.go(fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHigh,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _handleBack(context),
            )
          : null,
      title: !showBackButton ? title : null,
      automaticallyImplyLeading: false,
      bottom: showBackButton
          ? PreferredSize(
              preferredSize: const Size.fromHeight(88),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 28),
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.headlineMedium!
                          .copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      child: title,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
