import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/generated/l10n.dart';

export 'fake_session_auth.dart';

/// In-memory liblanis overrides for app tests. Call [LanisClient.reset] in tearDown.
List<Override> testLanisOverrides() => LanisClient.configure();

List<LocalizationsDelegate<dynamic>> get testLocalizationsDelegates => [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

/// Pumps [child] under [ProviderScope] + MaterialApp with l10n.
Future<ProviderContainer> pumpTestApp(
  WidgetTester tester, {
  required Widget child,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) async {
  final allOverrides = [...testLanisOverrides(), ...overrides];
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: allOverrides,
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            builder: (context, child) => MaterialUiCompatibilityBridge(
              child: child ?? const SizedBox.shrink(),
            ),
            locale: locale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: child,
          );
        },
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Minimal router for screens that call [GoRouter.go] / [context.go].
Future<ProviderContainer> pumpTestRouterApp(
  WidgetTester tester, {
  required List<RouteBase> routes,
  required String initialLocation,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) async {
  final allOverrides = [...testLanisOverrides(), ...overrides];
  late ProviderContainer container;
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: routes,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: allOverrides,
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return MaterialApp.router(
            builder: (context, child) => MaterialUiCompatibilityBridge(
              child: child ?? const SizedBox.shrink(),
            ),
            locale: locale,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            routerConfig: router,
          );
        },
      ),
    ),
  );
  await tester.pump();
  return container;
}

void resetAuthTestSeams() {
  AuthController.resetDebugAuth();
  LanisClient.reset();
}
