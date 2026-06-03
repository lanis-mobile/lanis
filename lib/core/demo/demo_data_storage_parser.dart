import 'package:lanis/applets/data_storage/parser.dart';
import 'package:lanis/models/datastorage.dart';

class DemoDataStorageParser extends DataStorageParser {
  DemoDataStorageParser(super.sph, super.appletDefinition);

  @override
  Future<(List<FileNode>, List<FolderNode>)> getHome() async {
    final folder = FolderNode('Klassenarbeiten', 1, 0, 'Alle Klassenarbeiten des Schuljahres');
    final files = [
      FileNode(
        name: 'KA_Mathematik_2026-04.pdf',
        id: 101,
        folderID: 1,
        downloadUrl: '',
        groesse: '245 KB',
        aenderung: '15.04.2026',
        hinweis: 'Klassenarbeit mit Lösungen',
      ),
      FileNode(
        name: 'KA_Deutsch_2026-03.pdf',
        id: 102,
        folderID: 1,
        downloadUrl: '',
        groesse: '312 KB',
        aenderung: '22.03.2026',
      ),
    ];
    return (files, [folder]);
  }
}
