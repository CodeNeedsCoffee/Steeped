# Linux target — test harness only

This platform folder exists solely so `flutter test integration_test/` can run the
real widget tree, real `dio` networking, and real `go_router` navigation headlessly
on Linux dev machines, where the Android emulator may not be usable (see the
project's actual platform scope in the top-level `README.md`, which is unchanged
by this folder's existence: **Android and iOS only**).

Do not:
- Ship a Linux build.
- Add Linux-specific product code or list Linux in store metadata.
- Assume plugins without a Linux implementation (`audio_service`,
  `background_downloader`) work here — integration tests that need them build the
  widget tree directly with fake/in-memory overrides instead of calling the real
  `main()` (see `integration_test/app_test.dart`).
