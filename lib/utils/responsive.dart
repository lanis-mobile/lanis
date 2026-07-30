import 'package:flutter/material.dart';

class Responsive {
  static const double tabletBreakpoint = 600;
  static const double conversationsSplitBreakpoint = 780; // ~130% of 600

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width > tabletBreakpoint;

  static bool isConversationsSplit(BuildContext context) =>
      MediaQuery.sizeOf(context).width > conversationsSplitBreakpoint;
}
