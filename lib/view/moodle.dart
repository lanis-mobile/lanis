import 'dart:convert';

import 'package:dio_cookie_manager/dio_cookie_manager.dart' as dio_plugin;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lanis/generated/l10n.dart';
import 'dart:io' as dio_core;

import '../core/connection_checker.dart';
import '../core/native_adapter_instance.dart';
import '../core/sph/sph.dart';
import '../utils/file_operations.dart';

class MoodleWebView extends StatefulWidget {
  const MoodleWebView({super.key});

  @override
  State<MoodleWebView> createState() => _MoodleWebViewState();
}

class _MoodleWebViewState extends State<MoodleWebView> {
  static const noInternetError = "net::ERR_INTERNET_DISCONNECTED";

  final CookieManager cookieManager = CookieManager.instance();

  ValueNotifier<bool> canGoBack = ValueNotifier(false);
  ValueNotifier<bool> canGoForward = ValueNotifier(false);
  ValueNotifier<int> progressIndicator = ValueNotifier(0);
  ValueNotifier<String> currentPageTitle = ValueNotifier("");

  String? error;
  WebUri? errorUrl;

  bool isLoginError = false;
  String loginError = "";
  bool noInternetLogin = false;

  bool showWebView = true;
  bool isLoggedIn = false;

  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;

  void addWebViewCookies(
    final List<dio_core.Cookie> cookies,
    List<String> urls,
  ) {
    for (int i = 0; i < cookies.length; i++) {
      cookieManager.setCookie(
        url: WebUri(urls[i]),
        name: cookies[i].name,
        value: cookies[i].value,
        path: cookies[i].path!,
        domain: cookies[i].domain,
        isHttpOnly: cookies[i].httpOnly,
        isSecure: cookies[i].secure,
      );
    }
  }

  Future<void> getCookies() async {
    if (!(await connectionChecker.connected)) {
      setState(() {
        isLoginError = true;
        noInternetLogin = true;
      });

      return;
    }

    setState(() {
      isLoginError = false;
      noInternetLogin = false;
    });

    try {
      final dio = Dio(BaseOptions(validateStatus: (status) => status != null));
      final jar = CookieJar();
      dio.httpClientAdapter = getNativeAdapterInstance();
      dio.options.followRedirects = false;
      dio.interceptors.add(dio_plugin.CookieManager(jar));

      final lastSchoolCookie = dio_core.Cookie(
        "schulportal_lastschool",
        sph!.account.schoolID.toString(),
      );
      lastSchoolCookie.domain = ".hessen.de";
      lastSchoolCookie.path = "/";
      lastSchoolCookie.secure = true;

      jar.saveFromResponse(Uri.parse("https://login.schulportal.hessen.de/"), [
        lastSchoolCookie,
      ]);

      final response1 = await dio.head(
        "https://mo${sph!.account.schoolID}.schulportal.hessen.de",
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
          "user": "${sph!.account.schoolID}.${sph!.account.username}",
          "user2": sph!.account.username,
          "password": sph!.account.password,
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

      dio.close();
      jar.deleteAll();

      addWebViewCookies(
        [moProd01Cookie, moodleId1Cookie, moodleSessionCookie],
        [location3, location4, location4],
      );

      webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(
            "https://mo${sph!.account.schoolID}.schulportal.hessen.de",
          ),
        ),
      );
      sph!.session.jar.saveFromResponse(Uri.parse(location3), [moProd01Cookie]);
      sph!.session.jar.saveFromResponse(Uri.parse(location4), [
        moodleId1Cookie,
        moodleSessionCookie,
      ]);

      setState(() {
        isLoggedIn = true;
      });
    } catch (e) {
      setState(() {
        isLoginError = true;

        if (e is dio_core.SocketException || e is DioException) {
          loginError = "Netzwerkfehler - $e";
        } else {
          loginError = e.toString();
        }
      });
    }
  }

  void refresh() {
    if (webViewController != null) {
      if (error != null) {
        webViewController!.loadUrl(urlRequest: URLRequest(url: errorUrl));

        error = null;
        errorUrl = null;

        return;
      }

      webViewController!.reload();
    }
  }

  @override
  void initState() {
    super.initState();

    getCookies();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    pullToRefreshController ??= PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
      onRefresh: refresh,
    );

    if (webViewController != null) {
      pullToRefreshController!.setColor(Theme.of(context).colorScheme.primary);
      pullToRefreshController!.setBackgroundColor(
        Theme.of(context).colorScheme.surfaceContainer,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Moodle"),
        leading: IconButton(
          onPressed: () async {
            setState(() {
              showWebView = false;
            });

            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Stack(
        children: [
          PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool res, _) async {
              if (res) {
                return;
              }

              final canGoBack = await webViewController!.canGoBack();
              if (canGoBack) {
                webViewController!.goBack();
              } else {
                setState(() {
                  showWebView = false;
                });

                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Visibility(
              visible: showWebView,
              child: InAppWebView(
                pullToRefreshController: pullToRefreshController,
                initialSettings: InAppWebViewSettings(
                  transparentBackground: true,
                ),
                onWebViewCreated: (controller) {
                  webViewController = controller;
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  error = null;

                  final WebUri uri = navigationAction.request.url!;

                  if (uri.rawValue.contains(
                        ".schulportal.hessen.de/login/logout.php",
                      ) ||
                      uri.rawValue.contains(
                        ".schulportal.hessen.de/index.php?logout=all",
                      )) {
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.rawValue.contains('start.schulportal.hessen.de')) {
                    setState(() {
                      showWebView = false;
                    });
                    Navigator.pop(context);
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (!uri.rawValue.contains(".schulportal.hessen.de")) {
                    await launchUrl(uri);

                    return NavigationActionPolicy.CANCEL;
                  }

                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStart: (controller, uri) async {
                  error = null;
                  errorUrl = null;

                  if (await controller.canGoBack()) {
                    canGoBack.value = true;
                  } else {
                    canGoBack.value = false;
                  }

                  if (await controller.canGoForward()) {
                    canGoForward.value = true;
                  } else {
                    canGoForward.value = false;
                  }
                },
                onLoadStop: (controller, url) async {
                  pullToRefreshController!.endRefreshing();
                  progressIndicator.value = 0;

                  setState(() {}); // error
                },
                onTitleChanged: (controller, title) {
                  currentPageTitle.value = title ?? "";
                },
                onPageCommitVisible: (controller, uri) async {
                  // Hack to enable pull to refresh in Moodle.
                  controller.evaluateJavascript(
                    source:
                        "document.documentElement.style.height = document.documentElement.clientHeight + 1 + 'px';",
                  );

                  // Hide logout buttons.
                  controller.evaluateJavascript(
                    source:
                        '''document.querySelector("div#user-action-menu a.dropdown-item[href*='/login/logout.php']").style.display = "none";''',
                  );
                  controller.evaluateJavascript(
                    source:
                        '''document.querySelector("div.navbar li a[href*='index.php?logout=']").style.display = "none";''',
                  );
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) {
                    pullToRefreshController!.endRefreshing();
                    progressIndicator.value = 0;
                    return;
                  }

                  progressIndicator.value = progress;
                },
                onReceivedError: (controller, request, response) async {
                  error = response.description;
                  errorUrl = request.url;

                  pullToRefreshController!.endRefreshing();
                  progressIndicator.value = 0;
                },
                onDownloadStartRequest: (controller, request) {
                  double fileSize = request.contentLength / 1000000;

                  showFileModal(
                    context,
                    FileInfo(
                      name:
                          request.suggestedFilename ??
                          sph!.storage.generateUniqueHash(request.url.rawValue),
                      url: request.url,
                      size: "(${fileSize.toStringAsFixed(2)} MB)",
                    ),
                  );
                },
              ),
            ),
          ),

          // Background
          if (!isLoggedIn || error != null) ...[
            Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.maxFinite,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Login
          if (!isLoggedIn && !isLoginError) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context).logInTitle,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ] else if (!isLoggedIn) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (noInternetLogin) ...[
                    const Icon(Icons.wifi_off, size: 60),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).noInternetConnection2,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ] else ...[
                    const Icon(Icons.warning, size: 60),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).errorOccurred,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        loginError,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await getCookies();
                    },
                    child: Text(AppLocalizations.of(context).tryAgain),
                  ),
                ],
              ),
            ),
          ],

          // Error
          if (error != null) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    error == noInternetError ? Icons.wifi_off : Icons.warning,
                    size: 60,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      error == noInternetError
                          ? AppLocalizations.of(context).noInternetConnection2
                          : AppLocalizations.of(context).errorOccurredWebsite,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (error != noInternetError) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                                horizontal: 8.0,
                              ),
                              child: Text(
                                AppLocalizations.of(context).error,
                                style: Theme.of(context).textTheme.labelLarge!
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              error ?? "",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4.0,
                              horizontal: 8.0,
                            ),
                            child: Text(
                              "URL",
                              style: Theme.of(context).textTheme.labelLarge!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            errorUrl?.rawValue ?? "Unknown error",
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: isLoggedIn
          ? SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder(
                    valueListenable: progressIndicator,
                    builder: (context, progress, _) {
                      return Visibility(
                        visible: progress != 0,
                        maintainSize: true,
                        maintainState: true,
                        maintainAnimation: true,
                        child: LinearProgressIndicator(value: progress / 100),
                      );
                    },
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        onPressed: () async {
                          if (error != null) {
                            await Clipboard.setData(
                              ClipboardData(
                                text: errorUrl?.rawValue ?? "Unknown error",
                              ),
                            );

                            return;
                          }

                          if (webViewController != null) {
                            await Clipboard.setData(
                              ClipboardData(
                                text: (await webViewController!.getUrl())!
                                    .rawValue,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.link),
                      ),
                      Expanded(
                        child: error == null
                            ? Center(
                                child: ValueListenableBuilder(
                                  valueListenable: currentPageTitle,
                                  builder: (context, title, _) => Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            : SizedBox.shrink(),
                      ),
                      ValueListenableBuilder(
                        valueListenable: canGoBack,
                        builder: (context, can, _) {
                          return IconButton(
                            onPressed: can
                                ? () {
                                    webViewController?.goBack();
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_back),
                          );
                        },
                      ),
                      ValueListenableBuilder(
                        valueListenable: canGoForward,
                        builder: (context, can, _) {
                          return IconButton(
                            onPressed: can
                                ? () {
                                    webViewController?.goForward();
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_forward),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
          : SizedBox.shrink(),
    );
  }
}
