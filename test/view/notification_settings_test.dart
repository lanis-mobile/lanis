import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/view/settings/subsettings/notifications.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

void main() {
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    LanisClient.reset();
  });

  for (final unmount in [true, false]) {
    testWidgets(
      'permission response ${unmount ? 'after disposal is harmless' : 'initializes mounted settings'}',
      (tester) async {
        final permission = Completer<int>();
        var requested = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) {
              expect(call.method, 'checkPermissionStatus');
              requested = true;
              return permission.future;
            });
        await pumpTestApp(tester, child: const NotificationSettings());
        expect(requested, isTrue);
        if (unmount) await tester.pumpWidget(const SizedBox.shrink());
        permission.complete(1);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!unmount) expect(find.byType(NotificationSettings), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
