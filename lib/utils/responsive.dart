import 'package:flutter/material.dart';

class Responsive {
  static const double tabletBreakpoint = 600;
  static const double splitViewBreakpoint = 780; // ~130% of 600

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width > tabletBreakpoint;

  /// Master–detail split for conversations and settings (nav rail stays on [isTablet]).
  static bool isSplitView(BuildContext context) =>
      MediaQuery.sizeOf(context).width > splitViewBreakpoint;
}
