import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/utils/whats_new.dart';

void main() {
  test('equal versions', () {
    expect(compareVersions('1.0.0', '1.0.0'), 0);
    expect(compareVersions('v1.2.3', '1.2.3'), 0);
  });

  test('newer patch / minor / major', () {
    expect(compareVersions('1.0.1', '1.0.0'), 1);
    expect(compareVersions('1.1.0', '1.0.9'), 1);
    expect(compareVersions('2.0.0', '1.9.9'), 1);
  });

  test('older version', () {
    expect(compareVersions('1.0.0', '1.0.1'), -1);
  });

  test('build number suffix after plus', () {
    expect(compareVersions('1.2.3+10', '1.2.3+9'), 1);
    expect(compareVersions('1.2.3+10', '1.2.3+10'), 0);
  });
}
