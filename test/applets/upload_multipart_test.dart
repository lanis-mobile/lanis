import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/lessons/student/upload_multipart.dart';

void main() {
  test('cloneMultipartFiles allows finalize after original was finalized', () async {
    final original = MultipartFile.fromBytes(
      utf8.encode('hello'),
      filename: 'a.txt',
    );

    // Simulate first failed request consuming the stream.
    await original.finalize().fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );

    expect(
      () => original.finalize(),
      throwsA(isA<StateError>()),
    );

    final clones = cloneMultipartFiles([original, original]);
    expect(clones, hasLength(2));

    final first = await clones[0].finalize().fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );
    final second = await clones[1].finalize().fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );

    expect(utf8.decode(first), 'hello');
    expect(utf8.decode(second), 'hello');
  });
}
