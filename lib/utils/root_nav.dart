import 'package:flutter/material.dart';

/// Pops a dialog/modal that was shown with [useRootNavigator] (the default
/// for [showDialog]). Using the nearest navigator would pop a shell route.
void popRootDialog(BuildContext context) {
  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) nav.pop();
}

/// Pushes an in-applet page onto the nearest (shell branch) navigator.
///
/// The phone bottom bar only wraps applet `…/home` routes, so branch pushes
/// cover it. Never uses the root navigator — avoids orphan stacks after a
/// phone ↔ tablet resize.
Future<T?> pushInShell<T extends Object?>(
  BuildContext context,
  Route<T> route,
) {
  return Navigator.of(context).push<T>(route);
}

/// Pushes an immersive overlay onto the root navigator (covers rail + bar).
///
/// Use for file pickers, fullscreen image viewers, and similar content that
/// is not part of shell navigation.
Future<T?> pushOverlay<T extends Object?>(
  BuildContext context,
  Route<T> route,
) {
  return Navigator.of(context, rootNavigator: true).push<T>(route);
}

/// Shows a modal bottom sheet on the root navigator so it covers home chrome.
///
/// Defaults [useSafeArea] to true so content clears the system gesture/nav bar.
Future<T?> showRootModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: backgroundColor,
    barrierLabel: barrierLabel,
    elevation: elevation,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
  );
}
