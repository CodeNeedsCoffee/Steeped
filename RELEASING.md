# Releasing Steeped

## Versioning

- `pubspec.yaml` `version: MAJOR.MINOR.PATCH+BUILD`.
  - **MAJOR**: a break in what the app needs from the server or in saved data that cannot migrate.
  - **MINOR**: user-visible features (a phase from PLAN.md). Reset PATCH to 0.
  - **PATCH**: fixes only.
  - **BUILD**: increases on every store upload (both stores reject a repeated build number).
- Tag releases `vMAJOR.MINOR.PATCH` on the commit that was submitted.

## Changelog

- Add each user-visible change to **Unreleased** in [CHANGELOG.md](CHANGELOG.md) in the same commit as the change.
- At release, rename **Unreleased** to the version and date, and start a new empty **Unreleased**.
- The store "What's new" text is written from that section (plain language, no internal phase names).

## Release checklist

1. All tests pass (`flutter test`) and `flutter analyze` is clean of errors and warnings.
2. ROADMAP.md "To do" has nothing marked release-blocking; anything unverified on a device is listed there.
3. Update `pubspec.yaml` version, CHANGELOG.md and the tag.
4. **Permissions and data (PLAN.md Phase L):** diff the merged Android manifest and `ios/Runner/Info.plist` against the
   last release. For every new or changed permission, background mode or data use, update:
   - the Google Play Console (Data safety, permission and foreground-service declarations),
   - App Store Connect (App Privacy, background modes, review notes with the demo login),
   - the privacy policy on the website (Steeped-Site repo, `src/worker/pages/privacy.ts`), **published before** submitting,
   - the in-app explanation shown before any permission prompt.
5. Refresh store screenshots and "What's new" if the UI changed.
6. Android: `flutter build appbundle`; iOS: the `main` branch build goes to App Review automatically, the `preview`
   branch goes to TestFlight (see README).
7. After approval, confirm the store pages show the new version and the policy URL works.
