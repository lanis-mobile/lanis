enum FileActions { download, upload, delete }

class FileNode {
  final String name;
  int id;
  int? folderID;
  String downloadUrl;
  String groesse;
  String aenderung;
  String? hinweis;
  List<FileActions> supportedActions = [FileActions.download];

  FileNode(
      {required this.name,
      required this.id,
      required this.downloadUrl,
      this.aenderung = "",
      this.groesse = "",
      this.hinweis,
      this.folderID});

  String get fileExtension => name.split('.').last;
}

class FolderNode {
  String name;
  int id;
  int subfolders;
  String desc;

  FolderNode(this.name, this.id, this.subfolders, this.desc);
}
