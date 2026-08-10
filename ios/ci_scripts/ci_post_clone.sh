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
# channel, for reproducibility -- update this alongside `flutter upgrade`
# locally. Clone by tag, not by commit SHA: Flutter computes its own
# version via `git describe --tags`, and a depth-1 fetch of a bare SHA
# doesn't bring the tag ref along, so the SDK reports itself as
# "0.0.0-unknown" and breaks pub's version solving for any plugin with a
# Flutter SDK constraint (broke on flutter_file_dialog in Build 8).
FLUTTER_VERSION="3.44.8"
git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios

cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter clean
flutter pub get

# `flutter pub get` regenerates FlutterGeneratedPluginSwiftPackage's
# Package.swift from scratch every time, always at Flutter's hardcoded
# default deployment target (iOS 13.0). The patch that raises it to match
# this project's real IPHONEOS_DEPLOYMENT_TARGET (14.0, which
# background_downloader requires) only runs inside the `flutter build`
# command itself (flutter_tools: SwiftPackageManager.updateMinimumDeployment,
# called from mac.dart's buildXcodeProject) -- not from `pub get`, and not
# from a raw `pod install`. Xcode Cloud's own archive step calls
# `xcodebuild` directly rather than going through the `flutter` CLI, so
# that patch never ran, which is why Build 7 and Build 9 both failed
# archiving with the identical 13.0/14.0 mismatch even after the
# unrelated Flutter-version fix in Build 8. `--config-only` runs
# Flutter's iOS project-config pipeline (deployment-target patch and Pods
# both included) without an actual build -- it's flutter_tools' own
# documented option for exactly this pattern of letting a separate tool
# perform the real archive.
flutter build ios --release --config-only --no-codesign
