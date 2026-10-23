import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/widgets/reset_account_page.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

class _Active extends ActiveAccount {
  @override
  ClearTextAccount build() => ClearTextAccount(
    localId: 1,
    schoolID: 1,
    username: 'u',
    password: 'p',
    schoolName: 'Test',
  );
}

class _Accounts extends Accounts {
  final removal = Completer<void>();
  int removals = 0;
  @override
  Future<List<AccountSummary>> build() async => [];
  @override
  Future<void> remove(int id) async {
    removals++;
    await removal.future;
  }
}

class _Auth extends AuthController {
  int bootstraps = 0;
  @override
  AuthState build() => const AuthState.authenticated();
  @override
  Future<void> bootstrap() async {
    bootstraps++;
  }
}

void main() {
  tearDown(LanisClient.reset);
  for (final unmount in [true, false]) {
    testWidgets(
      'account removal ${unmount ? 'after page disposal' : 'while mounted'} still bootstraps',
      (tester) async {
        final accounts = _Accounts();
        final auth = _Auth();
        final visible = ValueNotifier(true);
        addTearDown(visible.dispose);
        await pumpTestRouterApp(
          tester,
          initialLocation: '/',
          overrides: [
            activeAccountProvider.overrideWith(_Active.new),
            accountsProvider.overrideWith(() => accounts),
            authControllerProvider.overrideWith(() => auth),
          ],
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => ValueListenableBuilder(
                valueListenable: visible,
                builder: (_, show, _) =>
                    show ? const ResetAccountPage() : const SizedBox.shrink(),
              ),
            ),
            GoRoute(
              path: '/startup',
              builder: (_, _) => const Text('Startup destination'),
            ),
          ],
        );
        await tester.tap(
          find.widgetWithIcon(ElevatedButton, Icons.no_accounts),
        );
        await tester.pump();
        expect(accounts.removals, 1);
        if (unmount) {
          visible.value = false;
          await tester.pump();
          expect(find.byType(ResetAccountPage), findsNothing);
        }
        accounts.removal.complete();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(auth.bootstraps, 1);
        if (!unmount) expect(find.text('Startup destination'), findsOneWidget);
      },
    );
  }
}
