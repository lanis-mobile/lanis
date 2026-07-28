import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/privacy_policy.dart';

void main() {
  late LanisDatabase db;
  late TypedSettings shared;

  setUp(() {
    db = LanisDatabase.open();
    shared = TypedSettings.shared(db);
  });

  tearDown(() {
    db.dispose();
  });

  test('rejects when key missing', () {
    expect(isPrivacyPolicyAccepted(shared), isFalse);
  });

  test('rejects when accepted version is outdated', () {
    shared.setString(privacyPolicyAcceptedVersionKey, '2000-01-01');
    expect(isPrivacyPolicyAccepted(shared), isFalse);
  });

  test('accepts after acceptPrivacyPolicy', () {
    acceptPrivacyPolicy(shared);
    expect(isPrivacyPolicyAccepted(shared), isTrue);
    expect(
      shared.getString(privacyPolicyAcceptedVersionKey),
      privacyPolicyPublishedAt,
    );
  });

  test('rejects again after version constant would bump', () {
    acceptPrivacyPolicy(shared);
    shared.setString(privacyPolicyAcceptedVersionKey, '2099-01-01');
    // Stored value must equal the compile-time constant exactly.
    expect(
      shared.getString(privacyPolicyAcceptedVersionKey) ==
          privacyPolicyPublishedAt,
      isFalse,
    );
    expect(isPrivacyPolicyAccepted(shared), isFalse);
  });
}
