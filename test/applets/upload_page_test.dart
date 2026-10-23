import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lanis/applets/lessons/student/upload_page.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

class _OnlineChecker extends ConnectionChecker {
  @override
  Future<bool> testConnection() async => true;
}

class _ReadySession extends Session {
  final LanisSession session;
  _ReadySession(this.session);
  @override
  LanisSession build() => session;
}

final class _PickedFile extends PlatformFile {
  final File file;
  _PickedFile(this.file);
  @override
  String get name => 'test.txt';
  @override
  Uri get uri => file.uri;
  @override
  XFile get xFile => XFile(file.path);
  @override
  Future<int> length() async => file.lengthSync();
  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);
}

class _Picker extends FilePickerPlatform {
  final File file;
  _Picker(this.file);
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => [_PickedFile(file)];
}

class _Parser extends LessonsStudentParser {
  Completer<List<FileStatus>>? upload;
  final uploadStarted = Completer<void>();
  int infoCalls = 0;
  bool missingCourse = false;
  bool hasOwnFile = false;
  int deletions = 0;

  _Parser(super.ctx);

  @override
  Future<dynamic> getUploadInfo(String url) async {
    infoCalls++;
    return {
      'start': 'Mittwoch 1.1.20 0:00',
      'deadline': 'Donnerstag 1.1.99 0:00',
      'automatic_deletion': '1.1.2100',
      'course_id': missingCourse ? null : 'course',
      'entry_id': 'entry',
      'upload_id': 'upload',
      'upload_multiple_files': true,
      'upload_any_number_of_times': true,
      'allowed_file_types': ['TXT'],
      'max_file_size': '5MB',
      'visibility': 'teachers',
      'public_files': <PublicFile>[],
      'own_files': <OwnFile>[
        if (hasOwnFile)
          OwnFile(
            name: 'existing.txt',
            url: 'https://example.test/file',
            index: 'file',
            time: 'Today',
          ),
      ],
    };
  }

  @override
  Future<List<FileStatus>> uploadFile({
    required String course,
    required String entry,
    required String upload,
    required MultipartFile file1,
    MultipartFile? file2,
    MultipartFile? file3,
    MultipartFile? file4,
    MultipartFile? file5,
  }) async {
    uploadStarted.complete();
    return this.upload?.future ??
        [FileStatus(name: 'test.txt', status: 'erfolgreich')];
  }

  @override
  Future<String> deleteUploadedFile({
    required String course,
    required String entry,
    required String upload,
    required String file,
    required String userPasswordEncrypted,
  }) async {
    expect(course, 'course');
    expect(entry, 'entry');
    expect(upload, 'upload');
    expect(file, 'file');
    expect(userPasswordEncrypted, isNotEmpty);
    expect(userPasswordEncrypted, isNot('password'));
    deletions++;
    return '1';
  }
}

void main() {
  late _Parser parser;
  late LanisSession session;
  late LanisDatabase db;
  late Directory directory;
  late FilePickerPlatform previousPicker;

  setUp(() async {
    await initializeDateFormatting('de');
    directory = Directory.systemTemp.createTempSync('lanis_upload_');
    final file = File('${directory.path}/test.txt')..writeAsStringSync('test');
    previousPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _Picker(file);
    db = LanisDatabase.open();
    final account = ClearTextAccount(
      localId: 1,
      schoolID: 1,
      username: 'u',
      password: 'p',
      schoolName: 'Test',
    );
    session = LanisSession(
      account: account,
      config: const LanisConfig(),
      connectionChecker: _OnlineChecker(),
    );
    parser = _Parser(
      AppletContext(
        session: session,
        database: db,
        account: account,
        accountSettings: TypedSettings.account(db, 1),
      ),
    );
  });

  tearDown(() async {
    FilePickerPlatform.instance = previousPicker;
    parser.dispose();
    await session.dispose();
    session.connectionChecker.dispose();
    db.dispose();
    directory.deleteSync(recursive: true);
    LanisClient.reset();
  });

  Future<void> startUpload(WidgetTester tester) async {
    await pumpTestApp(
      tester,
      child: const UploadScreen(url: 'test', name: 'Test upload', status: ''),
      overrides: [lessonsStudentParserProvider.overrideWithValue(parser)],
    );
    await tester.pumpAndSettle();
    final addButton = tester.widget<FloatingActionButton>(
      find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(FloatingActionButton),
      ),
    );
    late Future<void> picking;
    await tester.runAsync(() async {
      picking = Function.apply(addButton.onPressed!, const []) as Future<void>;
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.file_open_rounded));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    // Await the real callback through its local filesystem I/O.
    await tester.runAsync(() => picking);
    await tester.pump();
    expect(find.text('1 / 5'), findsOneWidget);
    // Isolate the pre-existing ListTile ink diagnostic from lifecycle failures.
    final diagnostic = tester.takeException();
    if (diagnostic != null) {
      expect(diagnostic, isA<FlutterError>());
      expect(
        diagnostic.toString(),
        startsWith(
          'ListTile background color or ink splashes may be invisible.',
        ),
      );
    }
    await tester.tap(find.byIcon(Icons.upload));
    await tester.pump();
  }

  testWidgets(
    'upload details action after its context is disposed is harmless',
    (tester) async {
      await startUpload(tester);
      await tester.pumpAndSettle();
      final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
      await tester.pumpWidget(const SizedBox.shrink());
      action.onPressed();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('upload details action still shows details while mounted', (
    tester,
  ) async {
    await startUpload(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('test.txt'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'upload finishing after disposal does not refresh disposed page',
    (tester) async {
      parser.upload = Completer<List<FileStatus>>();
      await startUpload(tester);
      expect(parser.uploadStarted.isCompleted, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      parser.upload!.complete([
        FileStatus(name: 'test.txt', status: 'erfolgreich'),
      ]);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(parser.infoCalls, 1);
    },
  );

  testWidgets('refresh after page disposal is harmless', (tester) async {
    await startUpload(tester);
    await tester.pumpAndSettle();
    final dynamic page = tester.state(find.byType(UploadScreen));
    await tester.pumpWidget(const SizedBox.shrink());
    page.forceReloadPage();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final missing in [true, false]) {
    testWidgets(
      'delete with ${missing ? 'missing' : 'valid'} course ID is handled',
      (tester) async {
        parser.missingCourse = missing;
        parser.hasOwnFile = true;
        session.cryptor.key = encrypt.Key.fromSecureRandom(46);
        await pumpTestApp(
          tester,
          child: const UploadScreen(
            url: 'test',
            name: 'Test upload',
            status: '',
          ),
          overrides: [
            lessonsStudentParserProvider.overrideWithValue(parser),
            sessionProvider.overrideWith(() => _ReadySession(session)),
          ],
        );
        await tester.pumpAndSettle();
        final delete = find.widgetWithIcon(IconButton, Icons.delete);
        await tester.ensureVisible(delete);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        if (find.byType(AlertDialog).evaluate().isNotEmpty) {
          await tester.enterText(find.byType(TextField), 'password');
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(FilledButton),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(parser.deletions, missing ? 0 : 1);
        if (missing) expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  }
}
