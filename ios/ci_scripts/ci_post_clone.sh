#!/bin/sh
set -e

# Xcode Cloud's macOS images don't include Flutter, so install it fresh on
# every run. This also regenerates ios/Flutter/Generated.xcconfig with a
# FLUTTER_ROOT that actually exists in this environment -- without that,
# the Xcode project's embedded "flutter build" run-script phase would fail
# looking for whatever machine-local path last ran `flutter pub get`.
git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios

cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

cd ios
pod install
