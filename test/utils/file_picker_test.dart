import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/utils/file_picker.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

void main() {
  const imageChannel = MethodChannel('plugins.flutter.io/image_picker');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  for (final invalid in [true, false]) {
    testWidgets(
      'camera filename ${invalid ? 'with separators is normalized' : 'without separators still moves'}',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'lanis_filename_',
        );
        final source = File('${directory.path}/image.jpg')
          ..writeAsStringSync('image');
        final cache = Directory('${directory.path}/cache')..createSync();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          imageChannel,
          (call) async => source.path,
        );
        messenger.setMockMethodCallHandler(
          pathChannel,
          (call) async => cache.path,
        );
        addTearDown(() {
          messenger.setMockMethodCallHandler(imageChannel, null);
          messenger.setMockMethodCallHandler(pathChannel, null);
          directory.deleteSync(recursive: true);
          LanisClient.reset();
        });
        late Future<Object?> result;
        await pumpTestApp(
          tester,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  result = pickFileUsingCamera(context).then<Object?>(
                    (value) => value,
                    onError: (Object error) => error,
                  );
                },
                child: const Text('Pick camera'),
              ),
            ),
          ),
        );
        await tester.runAsync(() => tester.tap(find.text('Pick camera')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          invalid ? 'folder/name' : 'safe-name',
        );
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        if (invalid && find.byType(AlertDialog).evaluate().isNotEmpty) {
          expect(source.existsSync(), isTrue);
          await tester.enterText(find.byType(TextField), 'safe-name');
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
        }
        final selected = await tester.runAsync(() => result);
        expect(selected, isA<PickedFile>());
        expect(
          (selected as PickedFile).path,
          '${cache.path}/${invalid ? 'foldername' : 'safe-name'}.jpg',
        );
        expect(File(selected.path!).existsSync(), isTrue);
        expect(source.existsSync(), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
