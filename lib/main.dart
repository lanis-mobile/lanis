import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/background_service.dart';
import 'package:lanis/bridge/sph_bootstrap.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/router.dart';
import 'package:lanis/themes.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/mono_text_viewer.dart';
import 'package:lanis/utils/phoenix.dart';
import 'package:lanis/utils/theme_settings.dart';
import 'package:lanis/view/startup_error_view.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    if (kReleaseMode) {
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return errorWidget(details);
      };
    }

    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

    final overrides = await bootstrapSphClient();

    enableTransparentNavigationBar();

    try {
      await setupBackgroundService();
      await initializeNotifications();
    } catch (e, stack) {
      logger.e('Failed to initialize background service and notifications');
      logger.e(e, stackTrace: stack);
    }

    await initializeDateFormatting();

    runApp(
      ProviderScope(
        overrides: overrides,
        child: Phoenix(child: const App()),
      ),
    );
  } catch (e, st) {
    logger.e(e, stackTrace: st);

    runApp(
      MaterialApp(
        home: Scaffold(
          body: StartupErrorView(
            errorDetails: FlutterErrorDetails(exception: e, stack: st),
          ),
        ),
      ),
    );
  }
}

Future<void> enableTransparentNavigationBar() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 29) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
        ),
      );
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(themeSettingsProvider);
    final router = ref.watch(goRouterProvider);

    late ThemeMode mode;
    late Themes theme;

    mode = snapshot['theme'] == 'system'
        ? ThemeMode.system
        : snapshot['theme'] == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;

    if (snapshot['color'] == 'standard') {
      theme = Themes.standardTheme;
    } else if (snapshot['color'] != 'standard' &&
        snapshot['color'] != 'dynamic') {
      if (Themes.flutterColorThemes.containsKey(snapshot['color'])) {
        theme = Themes.flutterColorThemes[snapshot['color']!]!;
      } else {
        theme = Themes.standardTheme;
      }
    } else {
      theme = Themes.standardTheme;
    }
    if (snapshot['is-amoled'] == true) {
      theme = Themes.getAmoledThemes(theme);
    }

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        if (lightDynamic != null && darkDynamic != null) {
          Themes.dynamicTheme = Themes.getNewTheme(lightDynamic.primary);
        }
        if (snapshot['color'] == 'dynamic') {
          var dynamicTheme = Themes.dynamicTheme;
          var darkTheme = dynamicTheme.darkTheme;
          if (snapshot['is-amoled'] == true) {
            darkTheme = Themes.getAmoledThemes(dynamicTheme).darkTheme;
          }
          theme = Themes(dynamicTheme.lightTheme, darkTheme);
        }

        if (mode == ThemeMode.light ||
            (mode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness ==
                    Brightness.light)) {
          BubbleStyles.init(theme.lightTheme!);
        } else if (mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark)) {
          BubbleStyles.init(
            theme.darkTheme ?? Themes.standardTheme.darkTheme!,
          );
        }

        return MaterialApp.router(
          title: 'Lanis Mobile',
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: mode,
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
        );
      },
    );
  }
}

Widget errorWidget(FlutterErrorDetails details, {BuildContext? context}) {
  if (context != null) AppLocalizations.of(context);

  String error = details.exception.toString();

  return Container(
    color: const Color.fromARGB(255, 249, 222, 220),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_rounded,
            size: 60,
            color: Color.fromARGB(255, 179, 38, 30),
          ),
          const SizedBox(height: 24),
          DefaultTextStyle(
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 179, 38, 30),
            ),
            child: Text(
              AppLocalizations.current.errorOccurred,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: const TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 179, 38, 30),
            ),
            child: Text(
              AppLocalizations.current.errorOccurredDetails(error),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: '${details.exception}\n${details.stack.toString()}',
                ),
              );
              if (context != null && context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MonoTextViewer(
                      report:
                          '${details.exception}\n${details.stack.toString()}',
                      title: 'Stack Trace',
                      fileNameStart: 'stack_trace_default',
                    ),
                  ),
                );
              }
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return const Color.fromARGB(255, 198, 40, 32);
                }
                return const Color.fromARGB(255, 179, 38, 30);
              }),
            ),
            child: Text(AppLocalizations.current.copyErrorToClipboard),
          ),
        ],
      ),
    ),
  );
}
