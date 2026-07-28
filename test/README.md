# Testing

Account-free CI runs **analyzer + unit/widget tests** only (no device builds, no live SPH login).

## Run locally (same as CI)

```bash
flutter pub get
dart run intl_utils:generate
flutter analyze --no-fatal-infos
flutter test

cd liblanis && dart pub get && dart test
```

## What is covered

- **App (`test/`)** — privacy helpers/gate, deep links, welcome/login validation (no network submit), startup error chrome, auth privacy hard-stop, themes/responsive/paths, GlitchTip options.
- **liblanis** — database / client edge cases. Applet **parser** groups are empty stubs with `TODO` until anonymized fixtures exist.

## Credentials and fixtures

- `.credentials.env` is **gitignored**. No test and no CI job reads it.
- Optional local recorder: `dart run tool/record_fixtures.dart`
- After recording, anonymize names/emails/IDs, commit only files under `liblanis/test/fixtures/`, then **delete** `.credentials.env`.
- Fixture bodies must not contain real usernames, emails, or school-specific personal data.

## Anonymization rules

- Replace the recorded username with `user-a`
- Replace emails with `user@example.com`
- Scrub long numeric IDs / conversation uniquids to placeholders (`conv-1`, `0000`)
- Prefer empty-state or minimal synthetic JSON/HTML when full pages are not needed
