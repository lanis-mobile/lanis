# Testing

Account-free CI runs **analyzer, unit/widget tests, and an Android debug build**
(no live SPH login).

## Run locally (same as CI)

```bash
flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos
flutter test
```

## What is covered

- **App (`test/`)** — privacy helpers/gate, deep links, welcome/login validation (no network submit), startup error chrome, auth privacy hard-stop, themes/responsive/paths, GlitchTip options.

Library tests for [`liblanis`](https://pub.dev/packages/liblanis) live in the [liblanis](https://github.com/lanis-mobile/liblanis) repository.

## iOS scene lifecycle

Use Flutter 3.50 or newer (Dart 3.13 minimum). The app uses `FlutterSceneDelegate` with the `Main`
storyboard, and registers plugins through `FlutterImplicitEngineDelegate`.
`background_fetch` 2.0.1 or newer is required for scene lifecycle support.

On macOS with Xcode and an installed iOS simulator, build the app and run the
native launch regression tests (replace the destination with an available device):

```bash
flutter build ios --simulator --debug
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  -jobs 2 CODE_SIGN_IDENTITY=-
```

These tests check that a connected scene owns the Flutter window, its engine is
running with the startup plugins registered, and notification delivery still uses
the app delegate. Run on iOS 27 and an older supported iOS version.

For a device smoke test, cold-launch, background and resume the app, then open a
`lanis://common/settings/home` link both while running and after terminating it.
With a signed-in account, verify notification delivery and background fetch on a
physical device; simulator launch tests do not verify OS-scheduled fetches.

## Localization

Edit the English template (`lib/l10n/intl_en.arb`) and German translations
(`lib/l10n/intl_de.arb`), then run `flutter gen-l10n`. The generated Dart files
remain ignored by Git and are recreated by Flutter from `l10n.yaml`.
English remains the fallback language. Missing German messages are reported by
the generator and fall back to the English template.

Preserve the ordered placeholder metadata for `dateTimeString`: its positional
API takes day name, date, then time. Localization regression tests cover this
ordering, plural/select messages, locale fallback, and implicit `intl` formatting.
