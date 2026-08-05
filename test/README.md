# Testing

Account-free CI runs **analyzer + unit/widget tests** only (no device builds, no live SPH login).

## Run locally (same as CI)

```bash
flutter pub get
dart run intl_utils:generate
flutter analyze --no-fatal-infos
flutter test
```

## What is covered

- **App (`test/`)** — privacy helpers/gate, deep links, welcome/login validation (no network submit), startup error chrome, auth privacy hard-stop, themes/responsive/paths, GlitchTip options.

Library tests for [`liblanis`](https://pub.dev/packages/liblanis) live in the [liblanis](https://github.com/lanis-mobile/liblanis) repository.
