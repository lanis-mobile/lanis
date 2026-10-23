import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/view/moodle.dart';
import 'package:liblanis/liblanis.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helpers/test_app.dart';

class _Offline extends ConnectionChecker {
  @override
  Future<bool> testConnection() async => false;
  @override
  Future<bool> get connected async => false;
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();
  final requests = <Uri>[];
  int reloads = 0;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params.uri);
  }

  @override
  Future<void> reload() async {
    reloads++;
  }
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  WebResourceErrorCallback? onError;
  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}
  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {
    onError = onWebResourceError;
  }
}

class _Cookies extends PlatformWebViewCookieManager {
  _Cookies(super.params) : super.implementation();
}

class _Widget extends PlatformWebViewWidget {
  _Widget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Platform extends WebViewPlatform {
  late _Controller controller;
  late _Delegate delegate;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _Controller(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _Delegate(params);
  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) => _Cookies(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _Widget(params);
}

void main() {
  tearDown(LanisClient.reset);
  for (final url in <String?>[null, '', 'https://example.test/moodle']) {
    testWidgets(
      'Moodle retry handles ${url == null
          ? 'absent'
          : url.isEmpty
          ? 'empty'
          : 'valid'} error URL',
      (tester) async {
        final platform = _Platform();
        final previous = WebViewPlatform.instance;
        WebViewPlatform.instance = platform;
        addTearDown(() {
          if (previous != null) WebViewPlatform.instance = previous;
        });
        final checker = _Offline();
        addTearDown(checker.dispose);
        await pumpTestApp(
          tester,
          child: const MoodleWebView(),
          overrides: [connectionCheckerProvider.overrideWithValue(checker)],
        );
        platform.delegate.onError!(
          WebResourceError(errorCode: -1, description: 'Load failed', url: url),
        );
        await tester.pump();
        final dynamic page = tester.state(find.byType(MoodleWebView));
        await page.refresh();
        expect(tester.takeException(), isNull);
        if (url == null || url.isEmpty) {
          expect(platform.controller.requests, isEmpty);
          expect(platform.controller.reloads, 1);
        } else {
          expect(platform.controller.requests, [Uri.parse(url)]);
          expect(platform.controller.reloads, 0);
        }
      },
    );
  }
}
