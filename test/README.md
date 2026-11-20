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

### Native iOS per-app language

`CFBundleLocalizations` in `ios/Runner/Info.plist` declares English and German so
iOS exposes its native per-app Language menu. Flutter continues to follow the OS
locale; there is no separate app-managed override.

The Language tile explains the native route and opens the supported app-settings
URL through `AppSettingsType.settings` on iOS. `appLocale` is Android-specific;
the plugin falls back to that same general app-settings URL on iOS. There is no
public URL for opening the language picker directly. Do not replace this with
private `App-Prefs` paths.

Verified on the iPhone 18 Pro / iOS 27.0 simulator:

- Settings → Apps → Lanis contains Preferred Language → Language.
- The Language row opens a navigable picker with English and Deutsch.
- Selecting Deutsch makes Lanis render German while Settings remains English.
- German persists after terminating and relaunching Lanis.
- Selecting English restores the device's default language for Lanis.

The app-settings URL opened Settings but did not reliably navigate to Lanis: it
initially showed Settings home and later resumed the previous native page. The
instruction dialog therefore includes the verified manual route, with the older
iOS route as a fallback. Verify this shortcut on a physical device before claiming
it always opens Lanis's page directly; simulator verification cannot establish
that behavior for every supported OS version.
