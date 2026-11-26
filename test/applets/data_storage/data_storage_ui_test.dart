import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/data_storage/data_storage_ui.dart';
import 'package:lanis/applets/data_storage/folder_listtile.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('parseFolderColor', () {
    test('returns null for default black and invalid values', () {
      expect(parseFolderColor(null), isNull);
      expect(parseFolderColor(''), isNull);
      expect(parseFolderColor('#000000'), isNull);
      expect(parseFolderColor('#000'), isNull);
      expect(parseFolderColor('not-a-color'), isNull);
    });

    test('parses 6-digit and 3-digit hex colors', () {
      expect(parseFolderColor('#1565c0'), const Color(0xFF1565C0));
      expect(parseFolderColor('#f60'), const Color(0xFFFF6600));
    });
  });

  group('buildFolderRouteUri', () {
    test('preserves folder names containing slashes and parent segments', () {
      final raw = buildFolderRouteUri(
        31,
        title: 'Analysis & Kurvendiskussion',
        parentPath: const ['Dateispeicher', 'Demo: Schuljahr 2026/27'],
      );
      final parsed = Uri.parse(raw);
      expect(parsed.path, '/common/storage/folder/31');
      expect(parsed.queryParameters['title'], 'Analysis & Kurvendiskussion');
      expect(
        parsed.queryParametersAll['p'],
        const ['Dateispeicher', 'Demo: Schuljahr 2026/27'],
      );
    });
  });

  group('sorting', () {
    final files = [
      FileNode(
        name: 'b.txt',
        id: 1,
        downloadUrl: 'https://example.com/1',
        modifiedAt: DateTime(2026, 1, 10),
        sizeBytes: 500,
      ),
      FileNode(
        name: 'a.pdf',
        id: 2,
        downloadUrl: 'https://example.com/2',
        modifiedAt: DateTime(2026, 5, 1),
        sizeBytes: 2048,
      ),
      FileNode(
        name: 'c.csv',
        id: 3,
        downloadUrl: 'https://example.com/3',
        modifiedAt: DateTime(2025, 12, 1),
        sizeBytes: 100,
      ),
    ];

    test('sorts by name, date, and size', () {
      expect(
        sortDataStorageFiles(files, DataStorageSortOrder.nameAsc)
            .map((f) => f.name),
        ['a.pdf', 'b.txt', 'c.csv'],
      );
      expect(
        sortDataStorageFiles(files, DataStorageSortOrder.nameDesc)
            .map((f) => f.name),
        ['c.csv', 'b.txt', 'a.pdf'],
      );
      expect(
        sortDataStorageFiles(files, DataStorageSortOrder.dateDesc)
            .map((f) => f.name),
        ['a.pdf', 'b.txt', 'c.csv'],
      );
      expect(
        sortDataStorageFiles(files, DataStorageSortOrder.sizeDesc)
            .map((f) => f.name),
        ['a.pdf', 'b.txt', 'c.csv'],
      );
      expect(
        sortDataStorageFiles(files, DataStorageSortOrder.sizeAsc)
            .map((f) => f.name),
        ['c.csv', 'b.txt', 'a.pdf'],
      );
    });
  });

  group('widgets', () {
    testWidgets('DirectoryPathSubtitle collapses leading segments when narrow',
        (tester) async {
      const segments = [
        'Dateispeicher',
        'Demo: Schuljahr 2026/27',
        'Mathematik',
        'Analysis & Kurvendiskussion',
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: DirectoryPathSubtitle(segments: segments),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, startsWith('… › '));
      expect(text.data, contains('Analysis & Kurvendiskussion'));
    });

    testWidgets('DirectoryPathSubtitle does not prepend ellipsis for a single overflowing segment',
        (tester) async {
      const segments = ['Sehr Langer Ordnername Ohne Uebergeordnete Ordner'];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              child: DirectoryPathSubtitle(segments: segments),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, 'Sehr Langer Ordnername Ohne Uebergeordnete Ordner');
      expect(text.data, isNot(startsWith('…')));
    });

    testWidgets('FolderListTile shows custom color and subfolder count',
        (tester) async {
      final folder = FolderNode(
        'Mathematik',
        31,
        2,
        'Arbeitsblätter',
        fileCount: 3,
        colorHex: '#2e7d32',
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FolderListTile(folder: folder),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mathematik'), findsOneWidget);
      expect(find.text('Arbeitsblätter'), findsOneWidget);
      expect(find.text('2 Ordner · 3 Dateien'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, const Color(0xFF2E7D32));
    });
  });
}
