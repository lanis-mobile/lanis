import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/view/login/school_selector.dart';

void main() {
  test('sanitize strips non-word chars and lowercases', () {
    expect(SchoolSelector.sanitize('Frankfurt am Main!'), 'frankfurtammain');
    expect(SchoolSelector.sanitize('  ABC-123  '), 'abc123');
    expect(SchoolSelector.sanitize(''), '');
  });
}
