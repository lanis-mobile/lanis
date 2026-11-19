# Testing

Account-free CI runs **analyzer, unit/widget tests, and an Android debug build**
(no live SPH login).

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

## Dependency upgrade checks

Android compiles against API 37 while retaining Flutter's API 36 target and
API 24 minimum. Keep the legacy Kotlin/DSL flags until `cronet_http` supports
built-in Kotlin. iOS uses Swift Package Manager for plugins, including
TSBackgroundFetch and Sentry. CocoaPods integration has been removed; keep
minimum iOS 16. Camera permissions are detected from Info.plist by SPM, and
notification permissions are enabled by default.

Before release, verify an upgrade over an installed build with saved accounts:
secure storage 11 removes legacy cipher support. Include an older installation
that skipped the storage 10 migration, plus a current storage 10 installation.
Check account access after upgrading, background notifications, file picking and
saving, deep links, and networking without Google Play services. These checks
require retained app data or a physical device and are not covered by widget tests.
