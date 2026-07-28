import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/view/startup_error_view.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  testWidgets('StartupErrorView renders critical title and copy button', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      child: StartupErrorView(
        errorDetails: FlutterErrorDetails(
          exception: Exception('startup failed'),
          stack: StackTrace.current,
        ),
      ),
    );

    expect(find.text('Kritischer Fehler'), findsOneWidget);
    expect(find.text('Fehlerbericht kopieren'), findsOneWidget);
    expect(find.textContaining('startup failed'), findsOneWidget);
  });

  testWidgets('DeepLinkErrorPage shows app bar and error chrome', (tester) async {
    await pumpTestApp(
      tester,
      child: DeepLinkErrorPage(
        error: DeepLinkException('not available for your account'),
      ),
    );

    expect(find.byType(AppBar), findsWidgets);
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
  });
}
