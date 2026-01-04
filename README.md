# Lanis Mobile


Deine App für das hessische Schulportal! In Zusammenarbeit mit dem staatlichen Schulamt für den Landkreis Groß-Gerau und den Main-Taunus-Kreis
**Einsatz an zahlreichen Schulen in Hessen mit über 15K Nutzern**

<p align="center">
    <img src="https://github.com/alessioC42/lanis-mobile/assets/84250128/19d30436-32f7-4cbe-b78e-f2fee3583c28" width="60%">
</p>

<table>
    <tr>
        <td colspan='2'>
            <a href='https://play.google.com/store/apps/details?id=io.github.alessioc42.sph&pcampaignid=pcampaignidMKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1'><img alt='Jetzt bei Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/de_badge_web_generic.png' style='height: 71px'/></a>
        </td>
        <td colspan='2'>
            <a href="https://apt.izzysoft.de/fdroid/index/apk/io.github.alessioc42.sph"><img src="https://www.martinstoeckli.ch/images/izzy-on-droid-badge-en.png" alt="Get it on IzzyOnDroid" style="height: 56px;"></a>
        </td>
        <td colspan='2'>
            <a href='https://apps.apple.com/de/app/lanis-mobile/id6511247743?l=en-GB'><img alt='Jetzt im App Store' src='https://lanis-mobile.github.io/assets/ios-badge.svg' style='height: 61px'/></a>
        </td>
    </tr>
    <tr>
        <td colspan='3'>
            <a href='https://lanis-mobile.github.io/'>website</a>
        </td>
        <td colspan='3'>
            <a href='https://discord.gg/MGYaSetUsY'>discord</a>
        </td>
    </tr>
</table>

<p></p>
<details>
  <summary>Screenshots</summary>
<div style="text-align: center;">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/01.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/02.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/03.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/04.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/05.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/06.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/07.png" width="250" >

</div>
</details>

## Mitarbeit
Dieses Projekt ist stark von Bug-Reports anderer Schulen oder von neuen Mitarbeitern abhängig. Der Grund dafür liegt in
der modularen Natur des Schulportals, die es äußerst schwierig macht, eine universelle Lanis-App zu entwickeln.

Scheue dich nicht, einen Bug-Report zu erstellen, wenn du einen Fehler findest. Wir sind immer offen für neue Mitarbeiter/Schüler, die mit uns arbeiten, um die App zu verbessern.

Bug-Reports können auch an <a href="mailto:lanis-mobile@alessioc42.dev">diese</a> E-Mail-Adresse gesendet werden, falls kein Github-Konto vorhanden ist.

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
#### --dart-define=cronetHttpNoPlay=true
**[Partially optional]**
This flag is used to include the Cronet binary for networking on non-Play-Services-enabled devices (we also ship this version on the Play Store)

If you are currently using the default Android emulator image, consider using an AOSP image instead, as these tend to perform much better than versions with Play Services enabled.

On iOS builds this flag is not required.

#### --dart-define=ANSI=true 
**[Optional]**
This flag allows the application's logs to be colorized, which can help a lot if you are not already using your IDE's log-filtering tools. (Recommended to omit on macOS due to lack of support in the default Terminal)

### 4. Production
For actual release mode signing is required, which can be added via placing the respective `key.properties` and `local.properties` in the `android` directory. On iOS the Development team has to be changed in Xcode. 

If you are producing a build that you intend to distribute to other people, please consider changing the app ID from `io.github.alessioc42.sph` to `io.github.alessioc42.sph.<fork|dev>.<YOUR_NAME>` or any other name that is different from the original app ID. This will prevent conflicts with the store versions that we are publishing.

```shell
flutter build <apk|aab|ipa> --release --dart-define=cronetHttpNoPlay=true
```

An alternative is the `build.sh` script, which builds the android binarys when on linux and the macOS binarys when on macOS and opens the file manager with the build output when complete.