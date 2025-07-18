#!/bin/bash

OS=$(uname)

if [ "$OS" == "Darwin" ]; then
    echo "Building App Store IPA"
elif [ "$OS" == "Linux" ]; then
    echo "Building selfsigned APK and AAB files"
else
    echo "Unsupported operating system: $OS"
fi
echo ">>> flutter clean"
flutter clean
echo ">>> pub get"
flutter pub get
echo ">>> pub upgrade"
flutter pub upgrade
echo " pub outdated"
flutter pub outdated
echo ""
read -p "Press enter to continue..."
sleep 1
mkdir artifacts

echo ">>> generate localization files"
dart run intl_utils:generate


if [ "$OS" == "Darwin" ]; then

    echo ">>> build IPA"
    flutter build ipa
    mv build/ios/ipa/Lanis.ipa artifacts/Lanis.ipa

    open artifacts
elif [ "$OS" == "Linux" ]; then
    echo ">>> build appbundle"
    flutter build appbundle --dart-define=cronetHttpNoPlay=true
    mv build/app/outputs/bundle/release/app-release.aab artifacts/app-release.aab

    echo ">>> build apk"
    flutter build apk --dart-define=cronetHttpNoPlay=true
    mv build/app/outputs/flutter-apk/app-release.apk artifacts/app-release-selfsigned.apk

    xdg-open artifacts

    # Kill left over gradle daemons
    pkill -f '.GradleDaemon.'
fi
echo "done."
