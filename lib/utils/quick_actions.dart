import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/router.dart';
import 'package:lanis/utils/logger.dart';

late final QuickActions quickActions;
bool _quickActionsSet = false;
bool _requestFailed = false;

/// Maps SPH applet PHP URLs / external shortcut ids to go_router paths.
String? quickActionPathFor(String shortcutType) {
  switch (shortcutType) {
    case 'vertretungsplan.php':
      return '/home/substitutions';
    case 'kalender.php':
      return '/home/calendar';
    case 'stundenplan.php':
      return '/home/timetable';
    case 'nachrichten.php':
      return '/home/conversations';
    case 'meinunterricht.php':
      return '/home/lessons';
    case 'dateispeicher.php':
      return '/storage';
    case 'lerngruppen.php':
      return '/study-groups';
    case 'openMoodle':
      return '/moodle';
    default:
      return null;
  }
}

void _goQuickAction(String path) {
  final context = rootNavigatorKey.currentContext;
  if (context == null) {
    logger.e('Tried to open quick action without navigator context');
    return;
  }
  GoRouter.of(context).go(path);
}

class QuickActionsStartUp {
  static final Completer<void> _initializationCompleter = Completer<void>();
  bool _initialized = false;

  QuickActionsStartUp() {
    if (_initialized) return;
    quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      final path = quickActionPathFor(shortcutType);
      if (path != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Feature check for applets when a session is available.
          if (shortcutType.endsWith('.php')) {
            final context = rootNavigatorKey.currentContext;
            if (context != null) {
              final container = ProviderScope.containerOf(context);
              final supported =
                  container.read(supportedAppletPhpUrlsProvider);
              if (!supported.contains(shortcutType)) {
                logger.e('Applet not supported: $shortcutType');
                return;
              }
            }
          }
          logger.i('Opening quick action: $shortcutType -> $path');
          _goQuickAction(path);
        });
        return;
      }

      for (final applet in AppDefinitions.external) {
        if (applet.id == shortcutType) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            applet.action?.call(rootNavigatorKey.currentContext);
          });
          break;
        }
      }
    });
    logger.i('Initialized quick actions');
    _initializationCompleter.complete();
    _initialized = true;
  }

  static Future<bool> waitForInitialization() async {
    try {
      await _initializationCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
            throw TimeoutException('QuickActions initialization timed out.'),
      );
      return true;
    } on TimeoutException catch (_) {
      logger.e(
        'QuickActions initialization timed out. Likely the user is not logged in.',
      );
      return false;
    }
  }

  static void setNames(BuildContext context) async {
    if (_quickActionsSet) return;
    if (_requestFailed) return;
    var result = await waitForInitialization();
    if (!result) {
      _requestFailed = true;
      return;
    }
    if (_quickActionsSet) return;
    if (!context.mounted) return;

    final container = ProviderScope.containerOf(context);
    final shared = container.read(sharedOverAccountSettingsProvider);
    List<String> enabledShortcutsList = List<String>.from(
      shared.getJsonList('quick-actions') ?? [],
    );
    if (!context.mounted) return;

    List<ShortcutItem> shortcuts = [];
    for (final applet in AppDefinitions.applets) {
      if (enabledShortcutsList.contains(applet.appletPhpUrl)) {
        shortcuts.add(
          ShortcutItem(
            type: applet.appletPhpUrl,
            localizedTitle: applet.label(context),
            icon: '@mipmap/ic_launcher_monochrome',
          ),
        );
      }
    }
    for (final applet in AppDefinitions.external) {
      if (enabledShortcutsList.contains(applet.id)) {
        shortcuts.add(
          ShortcutItem(
            type: applet.id,
            localizedTitle: applet.label(context),
            icon: '@mipmap/ic_launcher_monochrome',
          ),
        );
      }
    }

    await quickActions.setShortcutItems(shortcuts);
    _quickActionsSet = true;
  }
}
