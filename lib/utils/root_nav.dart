import 'package:flutter/material.dart';

/// Pushes [route] onto the root navigator so it covers home chrome
/// (bottom [NavigationBar] / tablet [NavigationRail]).
Future<T?> pushRoot<T extends Object?>(
  BuildContext context,
  Route<T> route,
) {
  return Navigator.of(context, rootNavigator: true).push<T>(route);
}

/// Replaces the current root route (e.g. chat → chat).
Future<T?> pushRootReplacement<T extends Object?, TO extends Object?>(
  BuildContext context,
  Route<T> newRoute, {
  TO? result,
}) {
  return Navigator.of(context, rootNavigator: true).pushReplacement<T, TO>(
    newRoute,
    result: result,
  );
}

/// Shows a modal bottom sheet on the root navigator so it covers home chrome.
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
  bool useSafeArea = false,
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
