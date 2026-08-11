import 'package:dio/dio.dart';

/// Clone multipart payloads so Dio retries never reuse a finalized stream.
List<MultipartFile> cloneMultipartFiles(List<MultipartFile> files) {
  return files.map((file) => file.clone()).toList(growable: false);
}
