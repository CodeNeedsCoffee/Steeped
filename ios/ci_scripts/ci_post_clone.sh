#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Xcode Cloud's macOS images don't include Flutter, so install it fresh on
# every run. This also regenerates ios/Flutter/Generated.xcconfig with a
# FLUTTER_ROOT that actually exists in this environment -- without that,
# the Xcode project's embedded "flutter build" run-script phase would fail
# looking for whatever machine-local path last ran `flutter pub get`.
#
# Pinned to the exact revision this project already tracks in .metadata,
# rather than floating the stable channel: Build 7 failed archiving because
# a freshly-cloned stable tip generated FlutterGeneratedPluginSwiftPackage
# declaring iOS 13.0 support, conflicting with background_downloader's
# actual minimum of 14.0 -- even though Podfile/AppFrameworkInfo.plist/
# project.pbxproj all correctly say 14.0. Pinning to the same revision
# proven to build locally avoids depending on whatever stable resolves to
# on any given day.
FLUTTER_REVISION=$(grep 'revision:' .metadata | head -1 | sed 's/.*"\(.*\)"/\1/')
git init -q "$HOME/flutter"
cd "$HOME/flutter"
git remote add origin https://github.com/flutter/flutter.git
git fetch --depth 1 origin "$FLUTTER_REVISION"
git checkout -q FETCH_HEAD
export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios

cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

cd ios
pod install
