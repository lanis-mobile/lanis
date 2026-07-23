import 'dart:convert';
import 'dart:io';

import 'package:background_fetch/background_fetch.dart' as bgf;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_executor/flutter_background_executor.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/bridge/sph_bootstrap.dart';
import 'package:lanis/models/account_types.dart';
import 'package:lanis/utils/logger.dart';

Future<void> setupBackgroundService() async {
  if ((await Permission.notification.isDenied)) {
    logger.d('User disallowed notifications');
    await FlutterBackgroundExecutor().cancelAllTasks();
    return;
  }

  final overrides = await bootstrapSphClient();
  final container = ProviderContainer(overrides: overrides);
  try {
    final accounts = await container.read(accountsProvider.future);
    var disabledCount = 0;
    for (final account in accounts) {
      final settings = TypedSettings.account(
        container.read(lanisDatabaseProvider),
        account.localId,
      );
      if (settings.getBool('notifications-allow') == false) {
        disabledCount++;
      }
    }
    if (accounts.isNotEmpty && disabledCount == accounts.length) {
      await FlutterBackgroundExecutor().cancelAllTasks();
      return;
    }

    final shared = container.read(sharedOverAccountSettingsProvider);
    final targetIntervalMinutes =
        shared.getInt('notifications-target-interval-minutes') ?? 60;
    logger.i(
      'Setting up background task with interval of $targetIntervalMinutes minutes',
    );

    if (Platform.isAndroid) {
      await FlutterBackgroundExecutor().createRefreshTask(
        callback: callbackDispatcher,
        settings: RefreshTaskSettings(
          androidDetails: AndroidRefreshTaskDetails(
            requiresBatteryNotLow: true,
            requiresCharging: false,
            requiresDeviceIdle: false,
            requiresStorageNotLow: false,
            initialDelay: Duration.zero,
            repeatInterval: Duration(minutes: targetIntervalMinutes),
          ),
        ),
      );
      await FlutterBackgroundExecutor().runImmediatelyBackgroundTask(
        callback: callbackDispatcher,
      );
    }

    if (Platform.isIOS) {
      try {
        await bgf.BackgroundFetch.configure(
          bgf.BackgroundFetchConfig(
            minimumFetchInterval: targetIntervalMinutes,
          ),
          (String taskId) async {
            try {
              await callbackDispatcher();
            } finally {
              bgf.BackgroundFetch.finish(taskId);
            }
          },
          (String taskId) async {
            bgf.BackgroundFetch.finish(taskId);
          },
        );

        await bgf.BackgroundFetch.scheduleTask(
          bgf.TaskConfig(taskId: 'com.transistorsoft.notftask', delay: 10000),
        );
      } catch (e, s) {
        backgroundLogger.e(e, stackTrace: s);
      }
    }
  } finally {
    container.dispose();
  }
}

Future<void> initializeNotifications() async {
  try {
    FlutterLocalNotificationsPlugin().initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
  } catch (e, s) {
    backgroundLogger.e(e, stackTrace: s);
  }
}

@pragma('vm:entry-point')
Future<void> callbackDispatcher() async {
  try {
    backgroundLogger.i('Background fetch triggered');
    await initializeNotifications();

    final overrides = await bootstrapSphClient();
    final container = ProviderContainer(overrides: overrides);
    try {
      if (!await isTaskWithinConstraints(container)) {
        backgroundLogger.w('Task not within constraints... aborting');
        return;
      }

      if (!await container.read(connectionCheckerProvider).connected) {
        backgroundLogger.w('No network connection, aborting background fetch');
        return;
      }

      final accounts = await container.read(accountsProvider.future);

      // One shared activeAccount/session — must run accounts sequentially.
      for (final summary in accounts) {
        final db = container.read(lanisDatabaseProvider);
        final settings = TypedSettings.account(db, summary.localId);
        if (settings.getBool('notifications-allow') == false) {
          continue;
        }

        await container
            .read(activeAccountProvider.notifier)
            .select(summary.localId);
        final account = container.read(activeAccountProvider);
        if (account == null) continue;

        var authenticated = false;

        for (final applet in AppDefinitions.applets.where(
          (a) => a.notificationTask != null,
        )) {
          final accountType = account.accountType ?? AccountType.student;
          final enabled =
              settings.getBool('notification-${applet.appletPhpUrl}') ?? true;
          if (!applet.supportedAccountTypes.contains(accountType) ||
              !enabled) {
            continue;
          }

          if (!authenticated) {
            await container
                .read(sessionProvider.notifier)
                .authenticate(withoutData: true);
            authenticated = true;
          }

          final session = container.read(sessionProvider).asData?.value;
          if (session == null) continue;
          if (!session.doesSupportFeature(
            Applets.byPhpUrl(applet.appletPhpUrl),
            overrideAccountType: accountType,
          )) {
            continue;
          }

          // One shared session/Dio — run applet tasks sequentially.
          await applet.notificationTask!(
            container,
            accountType,
            BackgroundTaskToolkit(
              accountId: account.localId,
              username: account.username,
              schoolName: account.schoolName,
              settings: settings,
              appletId: applet.appletPhpUrl,
              multiAccount: accounts.length > 1,
            ),
          );
        }
        if (authenticated) {
          await container.read(sessionProvider.notifier).deAuthenticate();
        }
      }

      backgroundLogger.i('Background fetch completed');
    } finally {
      container.dispose();
    }
  } catch (e, s) {
    backgroundLogger.e('Error in background fetch');
    backgroundLogger.e(e, stackTrace: s);
  }
}

class BackgroundTaskToolkit {
  final int accountId;
  final String username;
  final String schoolName;
  final TypedSettings settings;
  final String appletId;
  final bool multiAccount;

  BackgroundTaskToolkit({
    required this.accountId,
    required this.username,
    required this.schoolName,
    required this.settings,
    required this.appletId,
    this.multiAccount = false,
  });

  /// Platform notification id: account + applet + local slot (0–9999).
  int _seedId(int id) {
    final appletSlot = (appletId.hashCode & 0x7fffffff) % 100;
    return id + appletSlot * 10000 + accountId * 1000000;
  }

  Future<void> sendMessage({
    required String title,
    required String message,
    int id = 0,
    bool avoidDuplicateSending = false,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) async {
    if (id > 10000 || id < 0) {
      throw ArgumentError('id must be between 0 and 10000');
    }
    id = _seedId(id);
    message = multiAccount
        ? '${username.toLowerCase()}@$schoolName\n$message'
        : message;
    if (avoidDuplicateSending) {
      final hash = hashString(message);
      final key = 'notif-dupe/$appletId/$id';
      if (settings.getString(key) == hash) {
        return;
      }
      settings.setString(key, hash);
    }
    try {
      final androidDetails = AndroidNotificationDetails(
        'io.github.alessioc42.sphplan',
        'lanis-mobile',
        channelDescription: 'Applet notifications',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(message),
        ongoing: false,
      );
      const iOSDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
      );
      await FlutterLocalNotificationsPlugin().show(
        id: id,
        title: title,
        body: message,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: iOSDetails,
        ),
      );
    } catch (e, s) {
      backgroundLogger.e(e, stackTrace: s);
    }
  }

  String hashString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}

Future<bool> isTaskWithinConstraints(ProviderContainer container) async {
  final shared = container.read(sharedOverAccountSettingsProvider);
  final days =
      shared.getJsonList('notifications-allowed-days') ??
      [true, true, true, true, true, false, false];
  final start =
      shared.getJsonList('notifications-start-time') ?? [6, 0];
  final end = shared.getJsonList('notifications-end-time') ?? [22, 0];

  final now = TimeOfDay.now();
  final startMinutes = (start[0] as int) * 60 + (start[1] as int);
  final endMinutes = (end[0] as int) * 60 + (end[1] as int);
  final nowMinutes = now.hour * 60 + now.minute;
  if (nowMinutes < startMinutes || nowMinutes > endMinutes) {
    return false;
  }
  final currentDayIndex = DateTime.now().weekday - 1;
  return days[currentDayIndex] == true;
}
