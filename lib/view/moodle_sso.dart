import 'dart:convert';
import 'dart:io' as dio_core;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart' as dio_plugin;

import '../core/native_adapter_instance.dart';

/// Checks if the given URI's host ends with the specified domain suffix.
/// This is secure against URL manipulation attacks.
bool isHostMatch(Uri uri, String domainSuffix) {
  final host = uri.host.toLowerCase();
  return host == domainSuffix || host.endsWith('.$domainSuffix');
}

/// Checks if the URI is a schulportal.hessen.de domain.
bool isSchulportalDomain(Uri uri) {
  return isHostMatch(uri, 'schulportal.hessen.de');
}

/// Cookies and URLs produced by the Moodle SSO redirect chain.
class MoodleSsoResult {
  final dio_core.Cookie moProd01Cookie;
  final dio_core.Cookie moodleId1Cookie;
  final dio_core.Cookie moodleSessionCookie;
  final String location3;
  final String location4;
  final String moodleHomeUrl;

  const MoodleSsoResult({
    required this.moProd01Cookie,
    required this.moodleId1Cookie,
    required this.moodleSessionCookie,
    required this.location3,
    required this.location4,
    required this.moodleHomeUrl,
  });
}

/// Performs the Schulportal → Moodle SSO login redirect chain.
///
/// Returns cookies for the Moodle webview / session jar, or throws on failure.
Future<MoodleSsoResult> performMoodleSso({
  required int schoolID,
  required String username,
  required String password,
}) async {
  final dio = Dio(BaseOptions(validateStatus: (status) => status != null));
  final jar = CookieJar();
  dio.httpClientAdapter = getNativeAdapterInstance();
  dio.options.followRedirects = false;
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (Response response, ResponseInterceptorHandler handler) {
        response.headers.forEach((name, values) {
          if (name.toLowerCase() == "set-cookie") {
            for (var i = 0; i < values.length; i++) {
              values[i] = values[i].replaceAll("HttpOnly=1", "HttpOnly");
            }
          }
        });
        return handler.next(response);
      },
    ),
  );
  dio.interceptors.add(dio_plugin.CookieManager(jar));

  final lastSchoolCookie = dio_core.Cookie(
    "schulportal_lastschool",
    schoolID.toString(),
  );
  lastSchoolCookie.domain = ".hessen.de";
  lastSchoolCookie.path = "/";
  lastSchoolCookie.secure = true;

  jar.saveFromResponse(Uri.parse("https://login.schulportal.hessen.de/"), [
    lastSchoolCookie,
  ]);

  final response1 = await dio.head(
    "https://mo$schoolID.schulportal.hessen.de",
  );
  final location_1 = response1.headers.value("location")!;

  // llngproxy01.schulportal.hessen.de
  final response2 = await dio.get(location_1);
  final location2 = response2.headers.value("location")!;

  // login.schulportal.hessen.de/saml/singleSignOn?SAMLRequest=...
  // Getting url out of a cookie for POST.
  await dio.get(location2);
  final cookies1 = await jar.loadForRequest(Uri.parse(location2));
  final sphSessionPDataCookie = cookies1
      .firstWhere((cookie) => cookie.name == "SPH-Sessionpdata")
      .value;
  final url = jsonDecode(Uri.decodeFull(sphSessionPDataCookie))["_url"];

  // login.schulportal.hessen.de/saml/singleSignOn?SAMLRequest=..
  final response3 = await dio.post(
    location2,
    options: Options(
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
    ),
    data: {
      "user": "$schoolID.$username",
      "user2": username,
      "password": password,
      "url": url,
    },
  );
  final location3 = response3.headers.value("location")!;

  // llngproxy01.schulportal.hessen.de/saml/proxySingleSignOnArtifact...
  final response4 = await dio.get(location3);
  final cookies2 = await jar.loadForRequest(Uri.parse(location3));
  final moProd01Cookie = cookies2.firstWhere(
    (cookie) => cookie.name == "mo-prod01",
  );
  final location4 = response4.headers.value("location")!;

  // mo{SCHOOLID}.schulportal.hessen.de/login/index.php
  await dio.get(location4);
  final cookies3 = await jar.loadForRequest(Uri.parse(location4));
  final moodleId1Cookie = cookies3.firstWhere(
    (cookie) => cookie.name == "MOODLEID1_",
  );
  final moodleSessionCookie = cookies3.firstWhere(
    (cookie) => cookie.name == "MoodleSession",
  );

  jar.deleteAll();

  return MoodleSsoResult(
    moProd01Cookie: moProd01Cookie,
    moodleId1Cookie: moodleId1Cookie,
    moodleSessionCookie: moodleSessionCookie,
    location3: location3,
    location4: location4,
    moodleHomeUrl: "https://mo$schoolID.schulportal.hessen.de",
  );
}
