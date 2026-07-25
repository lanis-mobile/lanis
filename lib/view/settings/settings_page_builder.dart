import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/widgets/large_appbar.dart';

abstract class SettingsColours extends StatefulWidget {
  const SettingsColours({super.key});
}

abstract class SettingsColoursState<T extends StatefulWidget> extends State<T> {
  Color foregroundColor = Colors.transparent;
  Color backgroundColor = Colors.transparent;
  Color sliderColor = Colors.transparent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applySettingsColours();
  }

  void _applySettingsColours() {
    if (Theme.of(context).brightness == Brightness.light) {
      foregroundColor = Theme.of(context).colorScheme.surfaceContainerLow;
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHigh;
      sliderColor = Theme.of(context).colorScheme.surfaceDim;
    } else {
      foregroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      backgroundColor = Theme.of(context).colorScheme.surfaceContainer;
      sliderColor = Theme.of(context).colorScheme.surfaceBright;
    }
  }
}

abstract class ConsumerSettingsColours extends ConsumerStatefulWidget {
  const ConsumerSettingsColours({super.key});
}

abstract class ConsumerSettingsColoursState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  Color foregroundColor = Colors.transparent;
  Color backgroundColor = Colors.transparent;
  Color sliderColor = Colors.transparent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Theme.of(context).brightness == Brightness.light) {
      foregroundColor = Theme.of(context).colorScheme.surfaceContainerLow;
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHigh;
      sliderColor = Theme.of(context).colorScheme.surfaceDim;
    } else {
      foregroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      backgroundColor = Theme.of(context).colorScheme.surfaceContainer;
      sliderColor = Theme.of(context).colorScheme.surfaceBright;
    }
  }
}

bool _effectiveShowBack(BuildContext context, bool showBackButton) {
  // Live width check so tablet→phone resize shows a back control.
  return showBackButton && !Responsive.isTablet(context);
}

class SettingsPage extends StatelessWidget {
  final Color backgroundColor;
  final Text title;
  final List<Widget> children;
  final EdgeInsets contentPadding;
  final void Function()? back;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final String? fallbackLocation;

  const SettingsPage({
    super.key,
    required this.backgroundColor,
    required this.title,
    this.contentPadding = EdgeInsets.zero,
    this.back,
    required this.children,
    this.floatingActionButton,
    this.showBackButton = true,
    this.fallbackLocation = SettingsDeepLinks.home,
  });

  @override
  Widget build(BuildContext context) {
    final showBack = _effectiveShowBack(context, showBackButton);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: LargeAppBar(
        title: title,
        backgroundColor: backgroundColor,
        back: back,
        showBackButton: showBack,
        fallbackLocation: fallbackLocation,
      ),
      body: Padding(
        padding: contentPadding,
        child: children.length > 1
            ? ListView(children: children)
            : children.first,
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class SettingsPageWithRefreshIndicator extends StatelessWidget {
  final Color backgroundColor;
  final Text title;
  final List<Widget> children;
  final EdgeInsets contentPadding;
  final Future<void> Function() onRefresh;
  final void Function()? back;
  final bool showBackButton;
  final String? fallbackLocation;

  const SettingsPageWithRefreshIndicator({
    super.key,
    required this.backgroundColor,
    required this.title,
    this.contentPadding = EdgeInsets.zero,
    this.back,
    required this.onRefresh,
    required this.children,
    this.showBackButton = true,
    this.fallbackLocation = SettingsDeepLinks.home,
  });

  @override
  Widget build(BuildContext context) {
    final showBack = _effectiveShowBack(context, showBackButton);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: LargeAppBar(
        title: title,
        backgroundColor: backgroundColor,
        back: back,
        showBackButton: showBack,
        fallbackLocation: fallbackLocation,
      ),
      body: Padding(
        padding: contentPadding,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(children: children),
        ),
      ),
    );
  }
}

typedef SettingsListBuilder =
    List<Widget> Function(
      BuildContext context,
      AsyncSnapshot<Map<String, dynamic>> snapshot,
    );

class SettingsPageWithStreamBuilder extends StatelessWidget {
  final Color backgroundColor;
  final Text title;
  final SettingsListBuilder builder;
  final EdgeInsets contentPadding;
  final void Function()? back;
  final Stream<Map<String, dynamic>> subscription;
  final bool showBackButton;
  final String? fallbackLocation;

  const SettingsPageWithStreamBuilder({
    super.key,
    required this.backgroundColor,
    required this.title,
    this.contentPadding = EdgeInsets.zero,
    this.back,
    required this.subscription,
    required this.builder,
    this.showBackButton = true,
    this.fallbackLocation = SettingsDeepLinks.home,
  });

  @override
  Widget build(BuildContext context) {
    final showBack = _effectiveShowBack(context, showBackButton);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: LargeAppBar(
        title: title,
        backgroundColor: backgroundColor,
        back: back,
        showBackButton: showBack,
        fallbackLocation: fallbackLocation,
      ),
      body: Padding(
        padding: contentPadding,
        child: StreamBuilder(
          stream: subscription,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return LinearProgressIndicator();
            }

            return ListView(children: builder(context, snapshot));
          },
        ),
      ),
    );
  }
}
