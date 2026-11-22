import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/utils/url_modal.dart';

void main() {
  group('isTrustedExternalUrl', () {
    test('accepts HTTPS exact domain and subdomains in trustedDomains', () {
      expect(
        isTrustedExternalUrl(Uri.parse('https://hessen.de/path')),
        isTrue,
      );
      expect(
        isTrustedExternalUrl(
          Uri.parse('https://start.schulportal.hessen.de/index.php'),
        ),
        isTrue,
      );
      expect(
        isTrustedExternalUrl(
          Uri.parse('https://lanis-mobile.alessioc42.dev/docs'),
        ),
        isTrue,
      );
      expect(
        isTrustedExternalUrl(Uri.parse('https://de.wikipedia.org/wiki/Test')),
        isTrue,
      );
    });

    test('rejects lookalike suffixes, non-HTTPS schemes, and empty hosts', () {
      expect(
        isTrustedExternalUrl(Uri.parse('https://evil-hessen.de/login')),
        isFalse,
      );
      expect(
        isTrustedExternalUrl(Uri.parse('https://phishingwikipedia.org/')),
        isFalse,
      );
      expect(
        isTrustedExternalUrl(Uri.parse('http://start.schulportal.hessen.de/')),
        isFalse,
      );
      expect(
        isTrustedExternalUrl(Uri.parse('javascript:alert(1)')),
        isFalse,
      );
      expect(
        isTrustedExternalUrl(Uri.parse('https://example.com/hessen.de')),
        isFalse,
      );
    });
  });
}
