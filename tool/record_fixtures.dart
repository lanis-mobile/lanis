// Local-only fixture recorder. Never invoked from CI.
//
// Usage (from repo root, with a gitignored `.credentials.env`):
//   dart run tool/record_fixtures.dart
//
// Credentials format:
//   schoolid=1234
//   username=example.user
//   password=secret
//
// After recording, review anonymized files under liblanis/test/fixtures/
// then delete `.credentials.env`. Tests must not read that file.

import 'dart:convert';
import 'dart:io';

/// Placeholder replacements applied before writing fixtures.
String anonymizeBody(String body, {required String username}) {
  var out = body;
  if (username.isNotEmpty) {
    out = out.replaceAll(username, 'user-a');
    out = out.replaceAll(username.toLowerCase(), 'user-a');
  }
  // Common PII-ish patterns — extend when reviewing real captures.
  out = out.replaceAll(
    RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
    'user@example.com',
  );
  out = out.replaceAll(
    RegExp(r'\b\d{4,}\b'),
    '0000',
  );
  return out;
}

Map<String, String> loadCredentials(File file) {
  final map = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final i = trimmed.indexOf('=');
    if (i <= 0) continue;
    map[trimmed.substring(0, i).trim().toLowerCase()] =
        trimmed.substring(i + 1).trim();
  }
  return map;
}

Future<void> main(List<String> args) async {
  final envPath = args.isNotEmpty ? args.first : '.credentials.env';
  final envFile = File(envPath);
  if (!envFile.existsSync()) {
    stderr.writeln(
      'Missing $envPath. Create it locally (gitignored), run this tool, '
      'then delete the credentials file. CI never uses it.',
    );
    exitCode = 1;
    return;
  }

  final creds = loadCredentials(envFile);
  final schoolId = creds['schoolid'];
  final username = creds['username'];
  final password = creds['password'];
  if (schoolId == null || username == null || password == null) {
    stderr.writeln('Expected schoolid, username, and password in $envPath');
    exitCode = 1;
    return;
  }

  final fixturesDir = Directory('liblanis/test/fixtures');
  await fixturesDir.create(recursive: true);
  await Directory('liblanis/test/fixtures/session').create(recursive: true);
  await Directory('liblanis/test/fixtures/applets').create(recursive: true);

  // Scaffold only: full Dio recording + login will be added when parser
  // fixtures are needed. Writing a manifest proves the anonymizer path.
  final sample = anonymizeBody(
    jsonEncode({
      'note': 'Replace with recorded SPH responses',
      'username': username,
      'schoolId': schoolId,
    }),
    username: username,
  );
  final manifest = File('liblanis/test/fixtures/RECORDING_README.json');
  await manifest.writeAsString(
    const JsonEncoder.withIndent('  ').convert(jsonDecode(sample)),
  );

  stdout.writeln(
    'Scaffolded $fixturesDir. Review ${manifest.path}, anonymize any '
    'future captures, commit fixtures only, then delete $envPath.\n'
    'TODO: wire LanisClient authenticate + recording HttpClientAdapter.',
  );
}
