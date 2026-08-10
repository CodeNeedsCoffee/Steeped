#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Xcode Cloud's macOS images don't include Flutter, so install it fresh on
# every run. This also regenerates ios/Flutter/Generated.xcconfig with a
# FLUTTER_ROOT that actually exists in this environment -- without that,
# the Xcode project's embedded "flutter build" run-script phase would fail
# looking for whatever machine-local path last ran `flutter pub get`.
#
# Pinned to a specific released version rather than floating the stable
# channel: Build 7 failed archiving because a freshly-cloned stable tip
# generated FlutterGeneratedPluginSwiftPackage declaring iOS 13.0 support,
# conflicting with background_downloader's actual minimum of 14.0 -- even
# though Podfile/AppFrameworkInfo.plist/project.pbxproj all correctly say
# 14.0. Update this alongside `flutter upgrade` locally.
#
# Clone by tag, not by the raw commit SHA from .metadata: Flutter computes
# its own version via `git describe --tags`, and a depth-1 fetch of a bare
# SHA doesn't bring along the tag ref pointing at it, so the SDK reported
# itself as "0.0.0-unknown" in Build 8 and broke pub's version solving for
# any plugin with a Flutter SDK constraint (flutter_file_dialog here).
# Cloning by tag makes that tag reachable immediately, with nothing to
# resolve.
FLUTTER_VERSION="3.44.8"
git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios

cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

cd ios
pod install
