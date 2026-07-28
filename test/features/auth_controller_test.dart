import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/auth/auth_controller.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(resetAuthTestSeams);

  test('bootstrap does not authenticate when privacy not accepted', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);

    await addTestAccount(container);
    final before = AuthController.authenticateCallCount;
    await container.read(authControllerProvider.notifier).bootstrap();

    expect(container.read(authControllerProvider).phase, AuthPhase.unauthenticated);
    expect(AuthController.authenticateCallCount, before);
  });

  test('bootstrap with privacy and empty accounts is unauthenticated', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);

    await container.read(authControllerProvider.notifier).bootstrap();
    expect(container.read(authControllerProvider).phase, AuthPhase.unauthenticated);
    expect(AuthController.authenticateCallCount, 0);
  });

  test('bootstrap with privacy and account succeeds via FakeSession', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    await addTestAccount(container);

    await container.read(authControllerProvider.notifier).bootstrap();
    expect(container.read(authControllerProvider).phase, AuthPhase.authenticated);
    expect(AuthController.authenticateCallCount, 1);
    expect(container.read(activeAccountProvider), isNotNull);
  });

  test('bootstrap WrongCredentials keeps account selected', () async {
    installFakeSessionAuth(result: FakeAuthResult.wrongCredentials);
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    final id = await addTestAccount(container);

    await container.read(authControllerProvider.notifier).bootstrap();
    final auth = container.read(authControllerProvider);
    expect(auth.phase, AuthPhase.error);
    expect(auth.exception, isA<WrongCredentialsException>());
    expect(container.read(activeAccountProvider)?.localId, id);
  });

  test('bootstrap NoConnection sets error', () async {
    installFakeSessionAuth(result: FakeAuthResult.noConnection);
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    await addTestAccount(container);

    await container.read(authControllerProvider.notifier).bootstrap();
    expect(container.read(authControllerProvider).phase, AuthPhase.error);
    expect(
      container.read(authControllerProvider).exception,
      isA<NoConnectionException>(),
    );
  });

  test('bootstrapIfNeeded no-ops when already authenticated', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    await addTestAccount(container);
    await container.read(authControllerProvider.notifier).bootstrap();
    final count = AuthController.authenticateCallCount;

    await container.read(authControllerProvider.notifier).bootstrapIfNeeded();
    expect(AuthController.authenticateCallCount, count);
  });

  test('bootstrapIfNeeded no-ops when in error', () async {
    installFakeSessionAuth(result: FakeAuthResult.wrongCredentials);
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    await addTestAccount(container);
    await container.read(authControllerProvider.notifier).bootstrap();
    expect(container.read(authControllerProvider).phase, AuthPhase.error);
    final count = AuthController.authenticateCallCount;

    await container.read(authControllerProvider.notifier).bootstrapIfNeeded();
    expect(AuthController.authenticateCallCount, count);
  });

  test('bootstrapIfNeeded no-ops while externally driven', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    final id = await addTestAccount(container);

    // Start loginWithAccount without awaiting bootstrapIfNeeded race:
    // login sets _authDrivenExternally before authenticate completes.
    var gate = false;
    installFakeSessionAuth(
      nextResult: () {
        if (!gate) {
          gate = true;
          // Still "in flight" from bootstrapIfNeeded's perspective after login started.
        }
        return FakeAuthResult.success;
      },
    );

    final loginFuture = container
        .read(authControllerProvider.notifier)
        .loginWithAccount(id);
    // After login starts, bootstrapIfNeeded should skip.
    await container.read(authControllerProvider.notifier).bootstrapIfNeeded();
    await loginFuture;
    expect(container.read(authControllerProvider).phase, AuthPhase.authenticated);
  });

  test('loginWithAccount success', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    final id = await addTestAccount(container);

    final ok = await container
        .read(authControllerProvider.notifier)
        .loginWithAccount(id);
    expect(ok, isTrue);
    expect(container.read(authControllerProvider).phase, AuthPhase.authenticated);
  });

  test('loginWithAccount privacy blocked', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    final id = await addTestAccount(container);

    final ok = await container
        .read(authControllerProvider.notifier)
        .loginWithAccount(id);
    expect(ok, isFalse);
    expect(AuthController.authenticateCallCount, 0);
  });

  test('loginWithAccount removeAccountOnFailure deletes account', () async {
    installFakeSessionAuth(result: FakeAuthResult.wrongCredentials);
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    final id = await addTestAccount(container);

    final ok = await container
        .read(authControllerProvider.notifier)
        .loginWithAccount(id, removeAccountOnFailure: true);
    expect(ok, isFalse);
    expect(await container.read(accountsProvider.future), isEmpty);
  });

  test('loginWithAccount failure restores previous account', () async {
    var call = 0;
    installFakeSessionAuth(
      nextResult: () {
        call++;
        // First auth (account A bootstrap path via select+auth on switch fail):
        // sequence: try B (fail), restore A (success).
        if (call == 1) return FakeAuthResult.wrongCredentials;
        return FakeAuthResult.success;
      },
    );
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    final idA = await addTestAccount(container, username: 'a');
    final idB = await addTestAccount(
      container,
      schoolId: 2,
      username: 'b',
    );

    // Establish A as active via successful login.
    installFakeSessionAuth();
    await container.read(authControllerProvider.notifier).loginWithAccount(idA);
    expect(container.read(activeAccountProvider)?.localId, idA);

    installFakeSessionAuth(
      nextResult: () {
        // Switching to B fails once; restore A succeeds.
        if (container.read(activeAccountProvider)?.localId == idB) {
          return FakeAuthResult.wrongCredentials;
        }
        return FakeAuthResult.success;
      },
    );

    final ok = await container
        .read(authControllerProvider.notifier)
        .loginWithAccount(idB);
    expect(ok, isFalse);
    expect(container.read(authControllerProvider).phase, AuthPhase.authenticated);
    expect(container.read(activeAccountProvider)?.localId, idA);
  });

  test('removeAccountAndContinue last account logs out', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    final id = await addTestAccount(container);
    await container.read(authControllerProvider.notifier).loginWithAccount(id);

    await container
        .read(authControllerProvider.notifier)
        .removeAccountAndContinue(id);
    expect(container.read(authControllerProvider).phase, AuthPhase.unauthenticated);
    expect(await container.read(accountsProvider.future), isEmpty);
  });

  test('removeAccountAndContinue bootstraps remaining account', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    final idA = await addTestAccount(container, username: 'a');
    final idB = await addTestAccount(container, schoolId: 2, username: 'b');
    await container.read(authControllerProvider.notifier).loginWithAccount(idA);

    await container
        .read(authControllerProvider.notifier)
        .removeAccountAndContinue(idA);
    expect(container.read(authControllerProvider).phase, AuthPhase.authenticated);
    expect(container.read(activeAccountProvider)?.localId, idB);
  });

  test('logout clears active account', () async {
    installFakeSessionAuth();
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    final id = await addTestAccount(container);
    await container.read(authControllerProvider.notifier).loginWithAccount(id);

    await container.read(authControllerProvider.notifier).logout();
    expect(container.read(authControllerProvider).phase, AuthPhase.unauthenticated);
    expect(container.read(activeAccountProvider), isNull);
  });

  test('retry after error can succeed', () async {
    var failOnce = true;
    installFakeSessionAuth(
      nextResult: () {
        if (failOnce) {
          failOnce = false;
          return FakeAuthResult.noConnection;
        }
        return FakeAuthResult.success;
      },
    );
    final container = createAuthTestContainer();
    addTearDown(container.dispose);
    acceptPrivacy(container);
    await addTestAccount(container);

    await container.read(authControllerProvider.notifier).bootstrap();
    expect(container.read(authControllerProvider).phase, AuthPhase.error);

    await container.read(authControllerProvider.notifier).retry();
    expect(container.read(authControllerProvider).phase, AuthPhase.authenticated);
  });
}
