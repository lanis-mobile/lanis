import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:liblanis/liblanis.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/logger.dart';

/// Authenticate, then fire-and-forget lanis-logger login telemetry when
/// [withoutData] is false and the app is in release mode (pre-v4 Session
/// behavior).
Future<LanisSession> authenticateWithLoginTelemetry(
  Session sessionController, {
  bool withoutData = false,
}) async {
  final session = await sessionController.authenticate(
    withoutData: withoutData,
  );
  if (!withoutData && kReleaseMode) {
    asyncLogLoginRequest(session);
  }
  return session;
}

/// Logs the login by schoolID and version code to the orion server.
///
/// server repo: https://github.com/lanis-mobile/school-monitor-backend
void asyncLogLoginRequest(LanisSession session) async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  try {
    String platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : 'unknown';
    await session.dio.post(
      "https://lanis-logger.orion.alessioc42.dev/api/log-login?schoolid=${session.account.schoolID}&versioncode=${packageInfo.buildNumber}&platform=$platform",
    );
    logger.i(
      'Logged account login to orion. (${session.account.schoolID}, ${packageInfo.buildNumber})',
    );
  } catch (e) {
    logger.w(
      'Failed to log account login to orion. (${session.account.schoolID}, ${packageInfo.buildNumber}) Likely the user in in a private network which only allows for school portal access.',
    );
  }
}
