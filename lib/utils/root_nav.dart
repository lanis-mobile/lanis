import 'package:flutter/material.dart';
import 'package:lanis/utils/responsive.dart';

bool _useRootNavigator(BuildContext context) => !Responsive.isTablet(context);

/// Pushes [route] for in-applet navigation.
///
/// On phone, uses the root navigator so the page covers the bottom bar.
/// On tablet, uses the current shell branch navigator so the [NavigationRail]
/// stays visible.
Future<T?> pushRoot<T extends Object?>(
  BuildContext context,
  Route<T> route,
) {
  return Navigator.of(
    context,
    rootNavigator: _useRootNavigator(context),
  ).push<T>(route);
}

/// Replaces the current route (e.g. chat → chat) with the same shell rules as
/// [pushRoot].
Future<T?> pushRootReplacement<T extends Object?, TO extends Object?>(
  BuildContext context,
  Route<T> newRoute, {
  TO? result,
}) {
  return Navigator.of(
    context,
    rootNavigator: _useRootNavigator(context),
  ).pushReplacement<T, TO>(
    newRoute,
    result: result,
  );
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
