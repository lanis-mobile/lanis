import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lanis/core/sph/sph.dart';

import '../../utils/logger.dart';

class StorageManager {
  final SPH sph;

  StorageManager({required this.sph});

  Future<Directory> getDocumentCacheDirectory() async {
    var tempDir = await getTemporaryDirectory();
    var userDir = Directory("${tempDir.path}/${sph.account.localId}");
    if (!userDir.existsSync()) {
      userDir.createSync();
    }
    String path = "${tempDir.path}/${sph.account.localId}/document_cache";
    Directory dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync();
    }
    return dir;
  }

  /// This function generates a unique hash for a given source string
  String generateUniqueHash(String source) {
    var bytes = utf8.encode(source);
    var digest = sha256.convert(bytes);

    var shortHash =
        digest.toString().replaceAll(RegExp(r'[^A-z0-9]'), '').substring(0, 12);

    return shortHash;
  }

  /// This function checks if a file exists in the temporary directory downloaded by [downloadFile]
  Future<bool> doesFileExist(String url, String filename) async {
    var tempDir = await getDocumentCacheDirectory();
    String urlHash = generateUniqueHash(url);
    String folderPath = "${tempDir.path}/$urlHash";
    String filePath = "$folderPath/$filename";

    File existingFile = File(filePath);
    return existingFile.existsSync();
  }

  ///downloads a file from an URL and returns the path of the file.
  ///
  ///The file is stored in the temporary directory of the device.
  ///So calling the same URL twice will result in the same file and one Download.
  Future<String> downloadFile(String url, String filename,
      {bool followRedirects = false}) async {
    try {
      var tempDir = await getDocumentCacheDirectory();
      String urlHash = generateUniqueHash(url);
      String folderPath = "${tempDir.path}/$urlHash";
      String savePath = "$folderPath/$filename";

      Directory folder = Directory(folderPath);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      if (await doesFileExist(url, filename)) {
        return savePath;
      }

      Response response = await sph.session.dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );
      if (response.statusCode == 302 && followRedirects) {
        logger.i("Following redirect to ${response.headers.value("location")}");
        if (response.headers.value("location")!.startsWith("https")) {
          url = response.headers.value("location")!;
        } else {
          Uri originalUrl = Uri.parse(url);
          String originalHost = originalUrl.host;
          url = "https://$originalHost/${response.headers.value("location")}";
        }

        response = await sph.session.dio.get(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
          ),
        );
      }

      File file = File(savePath);
      var raf = file.openSync(mode: FileMode.write);
      raf.writeFromSync(response.data);
      await raf.close();

      return savePath;
    } catch (e, stack) {
      logger.e(e, stackTrace: stack);
      return "";
    }
  }

  Future<void> deleteFilesOlderThan(Duration duration) async {
    var tempDir = await getDocumentCacheDirectory();
    var files = tempDir.listSync(recursive: true);
    for (var file in files) {
      if (file is File) {
        var stat = file.statSync();
        if (DateTime.now().difference(stat.modified).compareTo(duration) > 0) {
          file.deleteSync();
        }
      }
    }
  }
}
