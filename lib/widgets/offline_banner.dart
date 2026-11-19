import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/offline/foreground_connection_monitor.dart';
import 'package:lanis/generated/l10n.dart';

/// Shell chrome driven by global connectivity, independent of applet lifecycles,
/// loading states, and whether the current resource has a cached response.
class GlobalOfflineShell extends ConsumerWidget {
  final Widget child;
  const GlobalOfflineShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionStatusProvider).asData?.value;
    final interfaceAvailable = ref.watch(networkInterfaceAvailableProvider);
    return OfflineBannerLayout(
      offline:
          interfaceAvailable == false ||
          connection == ConnectionStatus.disconnected,
      child: child,
    );
  }
}

/// Explicit offline browsing supplies [offline] directly and does not construct
/// the authenticated session or connection checker.
class OfflineBannerLayout extends StatelessWidget {
  final bool offline;
  final Widget child;
  const OfflineBannerLayout({
    super.key,
    required this.offline,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Column(
    // Navigators block semantics of earlier siblings. Keep the shell status
    // after the navigator in traversal order while placing it above visually.
    verticalDirection: VerticalDirection.up,
    children: [
      Expanded(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: offline,
          child: child,
        ),
      ),
      if (offline)
        Container(
          key: const ValueKey('global-offline-banner'),
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: SafeArea(
            left: false,
            right: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context).offline,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
