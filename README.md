# Lanis Mobile

Deine App für das hessische Schulportal! In Zusammenarbeit mit dem staatlichen Schulamt für den Landkreis Groß-Gerau und den Main-Taunus-Kreis **Einsatz an zahlreichen Schulen in Hessen mit über 40 Tausend täglichen Nutzern.**




|                                            |                                          |     |
| ------------------------------------------ | ---------------------------------------- | --- |
|                                            |                                          |     |
| [website](https://lanis-mobile.github.io/) | [discord](https://discord.gg/MGYaSetUsY) |     |




Screenshots



## Mitarbeit

Dieses Projekt ist stark von Bug-Reports anderer Schulen oder von neuen Mitarbeitern abhängig. Der Grund dafür liegt in
der modularen Natur des Schulportals, die es äußerst schwierig macht, eine universelle Lanis-App zu entwickeln.

Scheue dich nicht, einen Bug-Report zu erstellen, wenn du einen Fehler findest. Wir sind immer offen für neue Mitarbeiter/Schüler, die mit uns arbeiten, um die App zu verbessern.

Bug-Reports können auch an [diese](mailto:lanis-mobile@alessioc42.dev) E-Mail-Adresse gesendet werden, falls kein Github-Konto vorhanden ist.

## Get started with development



### 1. [Setup Flutter](https://docs.flutter.dev/get-started/quick) with your favourite IDE (Android Studio / VScode recommended)



### 2. Generate the code

*You do not need to do this, if you cloned the repository freshly, since we have this checked into source control*

```shell
dart run build_runner build # Database
dart run intl_utils:generate # Localisations
```



### 3. Development

Note the flags here:

#### `--dart-define=cronetHttpNoPlay=true`

**[Partially optional]**
This flag is used to include the Cronet binary for networking on non-Play-Services-enabled devices (we also ship this version on the Play Store)

If you are currently using the default Android emulator image, consider using an AOSP image instead, as these tend to perform much better than versions with Play Services enabled.

On iOS builds this flag is not required.

#### `--dart-define=ANSI=true`

**[Optional]**
This flag allows the application's logs to be colorized, which can help a lot if you are not already using your IDE's log-filtering tools. (Recommended to omit on macOS due to lack of support in the default Terminal)

```shell
flutter run --dart-define=cronetHttpNoPlay=true --dart-define=ANSI=true
```



### 4. Production

For actual release mode signing is required, which can be added via placing the respective `key.properties` and `local.properties` in the `android` directory. On iOS the Development team has to be changed in Xcode. 

If you are producing a build that you intend to distribute to other people, please consider changing the app ID from `io.github.alessioc42.sph` to `io.github.alessioc42.sph.<fork|dev>.<YOUR_NAME>` or any other name that is different from the original app ID. This will prevent conflicts with the store versions that we are publishing.

```shell
flutter build <apk|aab|ipa> --release --dart-define=cronetHttpNoPlay=true
```

An alternative is the interactive `build.py` script, which can build Android and/or iOS in one run, copy artifacts into `artifacts/`, and optionally upload to App Store Connect / Google Play:

```shell
python3 build.py
# or non-interactive:
python3 build.py --android --ios --skip-upgrade --yes
```



#### Store uploads (optional)

`build.py` loads secrets from gitignored `.env` / `.build.env` in the repo root (real environment variables win). Example:

```env
ASC_API_KEY_ID=XXXXXXXXXX
ASC_API_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ASC_API_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8
PLAY_SERVICE_ACCOUNT_JSON=/path/to/service-account.json
```

Extra file: `python3 build.py --env-file /path/to/secrets.env`.

For Play uploads, install the optional Python deps and use a Google Cloud service account that has been invited in Play Console (Users and permissions) with permission to manage tracks:

```shell
pip install -r requirements-build.txt
python3 build.py --android --upload-android --play-track internal --yes
```

For App Store Connect uploads (macOS + Xcode), create an App Store Connect API key, put the values in `.env` (or export them), then:

```shell
python3 build.py --ios --upload-ios --yes
```

Uploads deliver the binary only (TestFlight / Play track). They do not submit for App Review or promote a production rollout.