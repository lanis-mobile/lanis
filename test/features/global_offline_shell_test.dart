import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/offline/foreground_connection_monitor.dart';
import 'package:lanis/widgets/offline_banner.dart';
import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  testWidgets(
    'global banner stays mounted across applets, loading, errors and details',
    (tester) async {
      late StateSetter changePage;
      var page = 'Timetable';
      final scope = await pumpTestApp(
        tester,
        child: StatefulBuilder(
          builder: (context, setState) {
            changePage = setState;
            return GlobalOfflineShell(
              child: Scaffold(
                appBar: AppBar(title: Text(page)),
                body: Text('$page content'),
              ),
            );
          },
        ),
      );
      final checker = scope.read(connectionCheckerProvider);
      checker.status = ConnectionStatus.connected;
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsNothing);

      checker.status = ConnectionStatus.disconnected;
      await tester.pumpAndSettle();
      final banner = find.byKey(const ValueKey('global-offline-banner'));
      expect(banner, findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      final element = tester.element(banner);
      final bounds = tester.getRect(banner);
      for (final next in [
        'Messages',
        'Loading',
        'Error',
        'Lessons',
        'Course detail',
        'Timetable',
      ]) {
        changePage(() => page = next);
        // Verify the first frame, without waiting for a child to report status.
        await tester.pump();
        expect(tester.element(banner), same(element));
        expect(tester.getRect(banner), bounds);
        expect(
          tester.getBottomLeft(banner).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(AppBar)).dy),
        );
        expect(find.text('Offline'), findsOneWidget);
      }
      checker.status = ConnectionStatus.connected;
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('shell banner remains accessible above nested route semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpTestApp(
        tester,
        child: OfflineBannerLayout(
          offline: true,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) =>
                  Scaffold(appBar: AppBar(title: const Text('Nested route'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Offline'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Offline')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(AppBar)).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'no network interface shows global status before applet or checker updates',
    (tester) async {
      final scope = await pumpTestApp(
        tester,
        child: const GlobalOfflineShell(child: Scaffold(body: Text('Loading'))),
      );
      scope.read(connectionCheckerProvider).status = ConnectionStatus.connected;
      scope.read(networkInterfaceAvailableProvider.notifier).update(false);
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      scope.read(networkInterfaceAvailableProvider.notifier).update(true);
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
