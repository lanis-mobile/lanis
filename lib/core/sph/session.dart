import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/core/database/account_database/account_db.dart';
import 'package:lanis/core/native_adapter_instance.dart';

import '../connection_checker.dart';
import 'cryptor.dart';
import '../../models/account_types.dart';
import '../../models/client_status_exceptions.dart';
import '../../utils/logger.dart';
import 'sph.dart';

class SessionHandler {
  SPH sph;
  String? schoolName;

  late Cryptor cryptor = Cryptor();
  late CookieJar jar;
  final dio = Dio();
  Timer? preventLogoutTimer;

  /// a Map containing the user data parsed from
  /// 'https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userData'
  Map<String, String> userData = {};
  AccountType? _accountType;

  /// Lanis fast travel menu obtained from
  /// 'https://start.schulportal.hessen.de/startseite.php?a=ajax&f=apps'
  List<dynamic> travelMenu = [];

  AccountType get accountType => _accountType ?? sph.account.accountType!;

  SessionHandler({
    required this.sph,
    String? withLoginURL,
  });

  Future<void> prepareDio() async {
    jar = CookieJar();
    dio.httpClientAdapter = getNativeAdapterInstance();
    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (Response response, ResponseInterceptorHandler handler) {
        if (response.data != null) {
          connectionChecker.status = ConnectionStatus.connected;
        } else {
          connectionChecker.status = ConnectionStatus.disconnected;
        }
        return handler.next(response);
      },
      onError: (DioException error, ErrorInterceptorHandler handler) {
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          connectionChecker.status = ConnectionStatus.disconnected;
        }
        return handler.next(error);
      },
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (Response response, ResponseInterceptorHandler handler) {
        if (response.data is String) {
          final contentType = response.headers.value('content-type');
          if (contentType != null && contentType.contains('text/html')) {
            final decryptedString = cryptor.decryptEncodedTags(response.data);
            //response.data = unescape.convert(decryptedString);
            response.data = decryptedString;
          }
        }
        return handler.next(response);
      },
    ));
    // dio.interceptors.add(InterceptorsWrapper(
    //   onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
    //     options.headers.addAll({
    //       'Cache-Control': 'no-cache',
    //       'Pragma': 'no-cache',
    //       'User-Agent': 'Lanis-Mobile'
    //     });
    //    options.queryParameters['_cachebreaker'] = DateTime.now().millisecondsSinceEpoch.toString();
    //     return handler.next(options);
    //   },
    // ));
    dio.options.followRedirects = false;
    dio.options.connectTimeout = Duration(seconds: 8);
    dio.options.validateStatus = (status) =>
        status != null && (status == 200 || status == 302 || status == 503);
  }

  ///Logs the user in and fetches the necessary metadata.
  Future<void> authenticate(
      {bool withoutData = false, String? withLoginUrl}) async {
    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    jar.deleteAll();
    dio.options.validateStatus = (status) =>
        status != null && (status == 200 || status == 302 || status == 503);

    late String loginURL;

    if (withLoginUrl != null) {
      loginURL = withLoginUrl;
    } else {
      loginURL = await getLoginURL(sph.account);
    }

    await dio.get(loginURL);

    preventLogoutTimer?.cancel();
    preventLogoutTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) => preventLogout());

    travelMenu = await getFastTravelMenu();
    if (!withoutData) {
      if (kReleaseMode) asyncLogRequest();
      accountDatabase.updateLastLogin(sph.account.localId);

      final response = await dio.get(
          "https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userData");
      userData = parseUserData(parse(response.data));
      _accountType = parseAccountType(parse(response.data));

      await accountDatabase.setAccountType(sph.account.localId, accountType);
    }

    await cryptor.initialize(dio);
  }

  /// Logs the login by schoolID and version code to the orion server.
  ///
  /// server repo: https://github.com/lanis-mobile/school-monitor-backend
  void asyncLogRequest() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    try {
      String platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'unknown';
      await dio.post(
          "https://lanis-logger.orion.alessioc42.dev/api/log-login?schoolid=${sph.account.schoolID}&versioncode=${packageInfo.buildNumber}&platform=$platform");
      logger.i(
          'Logged account login to orion. (${sph.account.schoolID}, ${packageInfo.buildNumber})');
    } catch (e) {
      logger.w(
          'Failed to log account login to orion. (${sph.account.schoolID}, ${packageInfo.buildNumber})');
    }
  }

  Future<void> deAuthenticate() async {
    logger.w(
        'Deauthenticating user [${sph.account.localId}] ${sph.account.schoolID}.${sph.account.username}');
    preventLogoutTimer?.cancel();
    await dio.get('https://start.schulportal.hessen.de/index.php?logout=all');
    jar.deleteAll();
  }

  ///returns a URL that when called loggs the user in.
  ///
  ///This can be used to open lanis in the browser of the user.
  static Future<String> getLoginURL(ClearTextAccount acc) async {
    final dioHttp = Dio();
    final cookieJar = CookieJar();
    dioHttp.httpClientAdapter = getNativeAdapterInstance();
    dioHttp.interceptors.add(CookieManager(cookieJar));
    dioHttp.options.followRedirects = false;
    dioHttp.options.validateStatus = (status) =>
        status != null && (status == 200 || status == 302 || status == 503);

    final response1 = await dioHttp.post(
        "https://login.schulportal.hessen.de/?i=${acc.schoolID}",
        queryParameters: {
          "user": '${acc.schoolID}.${acc.username}',
          "user2": acc.username,
          "password": acc.password,
        },
        options: Options(contentType: "application/x-www-form-urlencoded"));

    if (response1.statusCode == 503) {
      throw LanisDownException();
    }

    final loginTimeout =
        parse(response1.data).getElementById("authErrorLocktime");

    if (response1.headers.value(HttpHeaders.locationHeader) != null) {
      final response2 =
          await dioHttp.get("https://connect.schulportal.hessen.de");

      String location2 =
          response2.headers.value(HttpHeaders.locationHeader) ?? "";

      return location2;
    } else if (loginTimeout != null) {
      throw LoginTimeoutException(loginTimeout.text,
          "Zu oft falsch eingeloggt! Für den nächsten Versuch musst du ${loginTimeout.text}s warten!");
    } else {
      throw WrongCredentialsException();
    }
  }

  ///Periodically sends a request to the server to prevent the user from being logged out.
  ///Without this the user cannot access encrypted data after 3-4 minutes.
  Future<void> preventLogout() async {
    final uri = Uri.parse("https://start.schulportal.hessen.de/ajax_login.php");
    String sid;
    try {
      sid = (await jar.loadForRequest(uri))
          .firstWhere((element) => element.name == "sid")
          .value;
    } on StateError {
      return;
    }
    logger.i("Refreshing session");
    try {
      var response = await dio.post(
        "https://start.schulportal.hessen.de/ajax_login.php",
        data: 'name=${Uri.encodeComponent(sid)}',
        options: Options(
          contentType: "application/x-www-form-urlencoded",
          headers: {
            'x-requested-with': 'XMLHttpRequest',
          },
        ),
      );
      if (response.statusCode == 503) {
        throw LanisDownException();
      }
    } on DioException {
      return;
    }
  }

  ///returns the lanis fast navigation menubar.
  Future<dynamic> getFastTravelMenu() async {
    final response = await dio.get(
        "https://start.schulportal.hessen.de/startseite.php?a=ajax&f=apps");
    return jsonDecode(response.data.toString())["entrys"];
  }

  ///Parses the user data from the user data page.
  Map<String, String> parseUserData(Document document) {
    var userDataTableBody =
        document.querySelector("div.col-md-12 table.table.table-striped tbody");

    if (userDataTableBody != null) {
      Map<String, String> result = {};

      var rows = userDataTableBody.querySelectorAll("tr");
      for (var row in rows) {
        var key = row.children[0].text.trim();
        var value = row.children[1].text.trim();

        key = (key.substring(0, key.length - 1)).toLowerCase();

        result[key] = value;
      }

      return result;
    } else {
      return {};
    }
  }

  AccountType parseAccountType(Document document) {
    final iconClassList =
        document.querySelector('.nav.navbar-nav.navbar-right>li>a>i')!.classes;
    if (iconClassList.contains('fa-child')) {
      return AccountType.student;
    } else if (iconClassList.contains('fa-user-circle')) {
      return AccountType.parent;
    } else if (iconClassList.contains('fa-user')) {
      return AccountType.teacher;
    } else {
      logger.f('Unknown account type observed, while parsing account data');
      throw Exception('Unknown account type');
    }
  }

  bool doesSupportFeature(AppletDefinition applet,
      {AccountType? overrideAccountType}) {
    var app = travelMenu
        .where((element) => element["link"].toString() == applet.appletPhpUrl)
        .singleOrNull;
    if (app == null) {
      return false;
    }
    return applet.supportedAccountTypes
        .contains(overrideAccountType ?? accountType);
  }
}
