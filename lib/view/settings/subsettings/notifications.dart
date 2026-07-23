import 'dart:async';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/widgets/switch_tile.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/widgets/callout.dart';
import '../../../utils/logger.dart';
import 'package:lanis/widgets/range_slider_tile.dart';
import 'package:lanis/widgets/slider_tile.dart';

final Map<String, dynamic> _notificationDefaults = {
  "notifications-target-interval-minutes": 30,
  "notifications-allowed-days": [true, true, true, true, true, false, false],
  "notifications-start-time": Platform.isIOS ? [5, 30] : [6, 30],
  "notifications-end-time": Platform.isIOS ? [16, 30] : [15, 0],
};

class NotificationSettings extends ConsumerSettingsColours {
  final int? accountCount;
  final bool showBackButton;

  const NotificationSettings({
    super.key,
    this.accountCount,
    this.showBackButton = true,
  });

  @override
  ConsumerState<NotificationSettings> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState
    extends ConsumerSettingsColoursState<NotificationSettings> {
  final Map<String, AppletDefinition> supportedApplets = {};
  Map<String, dynamic> accountNotificationSettings = {
    'notifications-allow': true,
  };

  double targetNotificationInterval =
      _notificationDefaults['notifications-target-interval-minutes'].toDouble();
  List<bool> enabledDays = List<bool>.from(
    _notificationDefaults['notifications-allowed-days'],
  );
  TimeOfDay startTime = TimeOfDay(
    hour: _notificationDefaults['notifications-start-time'][0],
    minute: _notificationDefaults['notifications-start-time'][1],
  );
  TimeOfDay endTime = TimeOfDay(
    hour: _notificationDefaults['notifications-end-time'][0],
    minute: _notificationDefaults['notifications-end-time'][1],
  );

  PermissionStatus notificationPermissionStatus = PermissionStatus.provisional;
  Timer? checkTimer;

  void _loadSupportedApplets() {
    final supported = ref.read(supportedAppletPhpUrlsProvider);
    for (final applet in AppDefinitions.applets.where(
      (a) => a.notificationTask != null,
    )) {
      if (supported.contains(applet.appletPhpUrl)) {
        final key = 'notification-${applet.appletPhpUrl}';
        supportedApplets[key] = applet;
        accountNotificationSettings[key] =
            ref.read(accountSpecificSettingsProvider)?.getBool(key) ?? true;
      }
    }
  }

  void startPermissionCheck() {
    checkTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      final newStatus = await Permission.notification.status;
      if (newStatus != notificationPermissionStatus && mounted) {
        setState(() {
          notificationPermissionStatus = newStatus;
        });
      }
    });
  }

  void initVars() async {
    notificationPermissionStatus = await Permission.notification.status;
    final shared = ref.read(sharedOverAccountSettingsProvider);
    final accountSettings = ref.read(accountSpecificSettingsProvider);

    setState(() {
      notificationPermissionStatus = notificationPermissionStatus;
      targetNotificationInterval =
          (shared.getInt('notifications-target-interval-minutes') ??
                  _notificationDefaults['notifications-target-interval-minutes']
                      as int)
              .toDouble();
      final days =
          shared.getJsonList('notifications-allowed-days') ??
          _notificationDefaults['notifications-allowed-days'];
      enabledDays = days.map<bool>((e) => e as bool).toList();
      final start =
          shared.getJsonList('notifications-start-time') ??
          _notificationDefaults['notifications-start-time'];
      final end =
          shared.getJsonList('notifications-end-time') ??
          _notificationDefaults['notifications-end-time'];
      startTime = TimeOfDay(hour: start[0] as int, minute: start[1] as int);
      endTime = TimeOfDay(hour: end[0] as int, minute: end[1] as int);
      accountNotificationSettings['notifications-allow'] =
          accountSettings?.getBool('notifications-allow') ?? true;
      _loadSupportedApplets();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => initVars());
    startPermissionCheck();
  }

  @override
  void dispose() {
    checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(supportedAppletPhpUrlsProvider, (prev, next) {
      if (prev == next) return;
      setState(() {
        supportedApplets.clear();
        accountNotificationSettings.removeWhere(
          (k, _) => k.startsWith('notification-'),
        );
        _loadSupportedApplets();
      });
    });
    ref.listen(accountSpecificSettingsProvider, (prev, next) {
      if (identical(prev, next)) return;
      initVars();
    });
    ref.listen(activeAccountProvider, (prev, next) {
      if (prev?.localId == next?.localId) return;
      initVars();
    });

    final shared = ref.watch(sharedOverAccountSettingsProvider);
    final accountSettings = ref.watch(accountSpecificSettingsProvider);
    final resolvedAccountCount =
        widget.accountCount ??
        (ref.watch(accountsProvider).asData?.value.length ?? 1);

    List<String> applets = supportedApplets.keys.toList()..sort();

    final bool notificationsPermissionAllowed =
        notificationPermissionStatus == PermissionStatus.granted;
    final bool notificationsEnabled =
        (accountNotificationSettings['notifications-allow'] ?? true) == true;
    final bool notificationsActive =
        notificationsEnabled && notificationsPermissionAllowed;

    final bool activateBackgroundServices =
        (resolvedAccountCount == 1 && notificationsActive) ||
        resolvedAccountCount > 1;

    return SettingsPage(
      backgroundColor: backgroundColor,
      title: Text(AppLocalizations.of(context).notifications),
      showBackButton: widget.showBackButton,
      children: [
        if (!notificationsPermissionAllowed) ...[
          Callout(
            leading: Icon(Icons.error_rounded),
            title: Text(
              AppLocalizations.of(context).deniedNotificationPermissions,
            ),
            buttonText: Text(AppLocalizations.of(context).openSystemSettings),
            onPressed: () {
              AppSettings.openAppSettings(type: AppSettingsType.notification);
            },
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            buttonTextColor: Theme.of(context).colorScheme.onError,
            foregroundColor: Theme.of(context).colorScheme.error,
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
          ),
          SizedBox(height: 24.0),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GestureDetector(
            onTap: notificationsPermissionAllowed
                ? () {
                    final value = !notificationsEnabled;
                    accountSettings?.setBool('notifications-allow', value);
                    setState(() {
                      accountNotificationSettings['notifications-allow'] =
                          value;
                    });
                  }
                : null,
            child: Card.filled(
              color: notificationsPermissionAllowed
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ),
                child: MinimalSwitchTile(
                  title: Text(
                    AppLocalizations.of(context).useNotifications,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: notificationsPermissionAllowed
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  subtitle: resolvedAccountCount > 1
                      ? Text(AppLocalizations.of(context).forThisAccount)
                      : null,
                  value: notificationsEnabled,
                  onChanged: notificationsPermissionAllowed
                      ? (value) {
                          accountSettings?.setBool(
                            'notifications-allow',
                            value,
                          );
                          setState(() {
                            accountNotificationSettings['notifications-allow'] =
                                value;
                          });
                        }
                      : null,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 24.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Applets",
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: notificationsActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: 8.0),
        ...applets.map(
          (key) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: MinimalSwitchTile(
              title: Text(supportedApplets[key]?.label(context) ?? key),
              leading: Icon(supportedApplets[key]?.selectedIcon.icon),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
              value: (accountNotificationSettings[key] ?? true) == true,
              onChanged: notificationsActive
                  ? (value) async {
                      accountSettings?.setBool(key, value);
                      setState(() {
                        accountNotificationSettings[key] = value;
                      });
                      logger.i('Set $key to $value');
                    }
                  : null,
              useInkWell: true,
            ),
          ),
        ),
        SizedBox(height: 8.0),
        const Divider(),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 12.0),
          child: Text(
            "${AppLocalizations.of(context).backgroundService} ${resolvedAccountCount > 1 ? '(${AppLocalizations.of(context).forEveryAccount})' : ""}",
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: activateBackgroundServices
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: 8.0),
        Row(
          children: [
            SizedBox(width: 16.0),
            Icon(
              Icons.calendar_month,
              color: activateBackgroundServices
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 24.0),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8.0,
                  children: [
                    for (int dayIndex = 1; dayIndex < 8; dayIndex++)
                      FilterChip(
                        label: Text(
                          DateFormat.E(
                            Localizations.localeOf(context).languageCode,
                          ).dateSymbols.SHORTWEEKDAYS[dayIndex % 7],
                        ),
                        selected: enabledDays[dayIndex - 1],
                        onSelected: activateBackgroundServices
                            ? (val) {
                                setState(() {
                                  enabledDays[dayIndex - 1] = val;
                                });
                                shared.setJsonList(
                                  'notifications-allowed-days',
                                  enabledDays,
                                );
                              }
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 16.0),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0),
          child: RangeSliderTile(
            title: Row(
              children: [
                Text(
                  AppLocalizations.of(context).timePeriod,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: activateBackgroundServices
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Spacer(),
                Text(
                  "${startTime.format(context)} - ${endTime.format(context)}",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: activateBackgroundServices
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: 16.0),
              ],
            ),
            leading: Icon(
              Icons.schedule_outlined,
              color: activateBackgroundServices
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            values: RangeValues(
              minutesSinceZero(startTime).toDouble(),
              minutesSinceZero(endTime).toDouble(),
            ),
            max: 24 * 60,
            min: 0,
            divisions: 48,
            labels: RangeLabels(
              startTime.format(context),
              endTime.format(context),
            ),
            onChanged: activateBackgroundServices
                ? (newValues) {
                    setState(() {
                      startTime = timeFromMinutesSinceZero(
                        newValues.start.round(),
                      );
                      endTime = timeFromMinutesSinceZero(newValues.end.round());
                    });
                  }
                : null,
            onChangeEnd: (newValues) {
              shared.setJsonList('notifications-start-time', [
                startTime.hour,
                startTime.minute,
              ]);
              shared.setJsonList('notifications-end-time', [
                endTime.hour,
                endTime.minute,
              ]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: SliderTile(
            title: Row(
              children: [
                Text(
                  AppLocalizations.of(context).updateInterval,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: activateBackgroundServices
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Spacer(),
                Text(
                  "${targetNotificationInterval.round()} min",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: activateBackgroundServices
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: 16.0),
              ],
            ),
            leading: Icon(
              Icons.timer_outlined,
              color: activateBackgroundServices
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            value: targetNotificationInterval,
            onChanged: activateBackgroundServices
                ? (val) {
                    setState(() {
                      targetNotificationInterval = val;
                    });
                  }
                : null,
            onChangedEnd: (val) {
              shared.setInt(
                'notifications-target-interval-minutes',
                val.round(),
              );
            },
            label: "${targetNotificationInterval.round().toString()} min",
            min: 15.0,
            max: 180.0,
            divisions: 11,
            inactiveColor: sliderColor,
          ),
        ),
        SizedBox(height: 16.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20.0,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        SizedBox(height: 8.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            AppLocalizations.of(context).settingsInfoNotifications,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: 4.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: AppLocalizations.of(
                    context,
                  ).otherSettingsAvailablePart1,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: AppLocalizations.of(context).systemSettings,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      AppSettings.openAppSettings(
                        type: AppSettingsType.notification,
                      );
                    },
                ),
                TextSpan(
                  text: AppLocalizations.of(
                    context,
                  ).otherSettingsAvailablePart2,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (Platform.isAndroid)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: AppLocalizations.of(
                      context,
                    ).ignoreBatteryOptimizationPart1,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextSpan(
                    text: AppLocalizations.of(
                      context,
                    ).ignoreBatteryOptimizationSettings,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        final permStatus = await Permission
                            .ignoreBatteryOptimizations
                            .request();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                permStatus == PermissionStatus.granted
                                    ? AppLocalizations.of(
                                        context,
                                      ).ignoreBatteryOptimizationGranted
                                    : AppLocalizations.of(
                                        context,
                                      ).ignoreBatteryOptimizationDenied,
                                style: permStatus == PermissionStatus.granted
                                    ? Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                      )
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onErrorContainer,
                                      ),
                              ),
                              backgroundColor:
                                  permStatus == PermissionStatus.granted
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.errorContainer,
                            ),
                          );
                        }
                      },
                  ),
                  TextSpan(
                    text: AppLocalizations.of(
                      context,
                    ).otherSettingsAvailablePart2,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: 16.0),
      ],
    );
  }
}

int minutesSinceZero(TimeOfDay time) {
  return time.hour * 60 + time.minute;
}

TimeOfDay timeFromMinutesSinceZero(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  return TimeOfDay(hour: hour, minute: minute);
}
