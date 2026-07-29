# BooksNeedCoffee — Build Plan

A Flutter (single codebase, Android + iOS) client for a self-hosted **Audiobookshelf** server, aiming for feature parity with the official [audiobookshelf-app](https://github.com/advplyr/audiobookshelf-app) (server connection, streaming, downloads, local files, podcasts, e-books) but with a custom design system: a **glass/modern** look and a **user-selectable "skin"** (e.g. a literal wooden-bookshelf skin vs. a frosted-glass modern skin).

Reference material already on this machine:
- `~/Code/audiobookshelf-app` — official client source (Nuxt/Capacitor). Use it as a feature/behavior reference, not code to port directly — we're rebuilding natively in Dart.
- `~/Code/audiobookshelf` — the server source, useful when you need to confirm an API response shape.
- Official API docs: https://api.audiobookshelf.org

Legend for checkpoints:
- 🤖 **Android checkpoint** — build/run on your plugged-in Android device.
- 🍎 **Xcode checkpoint** — bigger landmark; open the project in Xcode on your Mac and build/run on Simulator or a device.

---

## Phase 0 — Tech Stack Decisions

- [ ] 0.1 State management: pick **Riverpod** (recommended — good for async server/streaming state) vs Bloc.
- [ ] 0.2 Navigation: **go_router** for declarative routing + deep links (useful later for "open this book" links).
- [ ] 0.3 Networking: **dio** (interceptors for auth headers/token refresh, better than plain `http`).
- [ ] 0.4 Local database: **drift** (SQLite) or **Isar** for library metadata, download records, playback progress cache.
- [ ] 0.5 Secure storage: **flutter_secure_storage** for server URL + auth token.
- [ ] 0.6 Audio playback: **just_audio** + **audio_service** (background playback, lock-screen controls, media notifications on both platforms).
- [ ] 0.7 Downloads: **background_downloader** (or `dio` + `flutter_downloader`) for resumable background downloads.
- [ ] 0.8 E-book rendering: `epub_view` (or `epubx`) for EPUB, `syncfusion_flutter_pdfviewer` or `pdfx` for PDF, `archive` package for CBZ/CBR comics.
- [ ] 0.9 Write these decisions into `README.md` once confirmed so future-you remembers why.

> 🤖 **Android checkpoint:** none needed yet — this phase is just decisions, no code.

---

## Phase 1 — Project Skeleton & Architecture

- [ ] 1.1 Define folder structure: `lib/core` (theme, networking, storage), `lib/features/<feature>` (auth, library, player, downloads, ebook, settings), `lib/models`, `lib/widgets` (shared components).
- [ ] 1.2 Add chosen packages to `pubspec.yaml`; run `flutter pub get`.
- [ ] 1.3 Set up Riverpod `ProviderScope` at app root.
- [ ] 1.4 Set up `go_router` with placeholder routes: splash, connect-to-server, login, home shell, settings.
- [ ] 1.5 Add lint rules (`flutter_lints` + any custom rules) and a pre-commit-friendly `analysis_options.yaml`.
- [ ] 1.6 Set up basic app icon + splash screen placeholders (`flutter_launcher_icons`, `flutter_native_splash`) — real branding comes later in Phase 9.

> 🤖 **Android checkpoint:** run the skeleton app on your device — confirm it launches, navigates between placeholder screens, and hot reload works end-to-end on real hardware.

---

## Phase 2 — Design System & Theming Engine

This is the "flare" layer — build it early as an engine, not one-off styles, since every later feature screen will consume it.

- [ ] 2.1 Define design tokens: color roles (background, surface, accent, text), spacing scale, radius scale, typography scale — as a `ThemeExtension` or custom `AppTheme` class (not hardcoded per-widget).
- [ ] 2.2 Build the **glass/modern skin**: frosted-glass surfaces (`BackdropFilter` + `ImageFilter.blur`), translucent cards, subtle gradients, dark-mode-first palette.
- [ ] 2.3 Build the **bookshelf skin**: warm wood/paper textures, skeuomorphic shelf grid for the library view, book-spine cover styling.
- [ ] 2.4 Build a **skin/theme switcher** abstraction: a `Skin` interface both themes implement, selectable at runtime, persisted to local storage (not just `ThemeMode` light/dark — a genuinely swappable design system).
- [ ] 2.5 Build core shared components against the token system: buttons, cards, list tiles, progress bars, bottom sheets, tab bar — so both skins reuse the same component tree with different token values.
- [ ] 2.6 Build a **Settings → Appearance** screen to preview and switch skins live.

> 🤖 **Android checkpoint:** run through both skins on-device, check for jank on the blur/glass effects (frosted blur is the most likely performance trap — verify real device framerate, not just emulator).

---

## Phase 3 — Server Connection & Authentication

- [ ] 3.1 Build the "Connect to Server" screen: enter server URL, validate reachability (ping a known Audiobookshelf endpoint).
- [ ] 3.2 Build login screen: username/password → auth token exchange against the Audiobookshelf API.
- [ ] 3.3 Support **multiple saved servers/accounts** (matches audiobookshelf-app behavior) with a switcher.
- [ ] 3.4 Store token + server URL in secure storage; wire a `dio` interceptor to attach the auth header and handle 401 (re-login) automatically.
- [ ] 3.5 Build a persisted "current user/session" provider so the rest of the app can read `me`.
- [ ] 3.6 Handle offline/unreachable-server states gracefully (needed later for the offline-downloads feature to make sense).

> 🤖 **Android checkpoint:** connect to your real Audiobookshelf server from the device over your home network, confirm login + token persistence survives app restart.

---

## Phase 4 — Library Browsing

- [ ] 4.1 Data models: Library, LibraryItem (book/podcast), Author, Series, Collection, Playlist — matching Audiobookshelf API shapes.
- [ ] 4.2 Fetch and list libraries; library switcher UI.
- [ ] 4.3 "Continue Listening" / latest / in-progress row (home shell).
- [ ] 4.4 Full library grid/list view — this is where the two skins diverge most (shelf-of-spines vs. modern grid of covers).
- [ ] 4.5 Authors browse screen, Series browse screen, Collections screen, Playlists screen.
- [ ] 4.6 Search (title/author/series, local client-side + server search endpoint).
- [ ] 4.7 Book/podcast detail screen: cover, description, metadata, chapter list, "Play"/"Download" actions.
- [ ] 4.8 Image caching for covers (`cached_network_image`) — important, covers are fetched constantly while browsing.

> 🤖 **Android checkpoint:** browse a real populated library end-to-end (scrolling perf on long lists, cover-image loading/caching, both skins).

---

## Phase 5 — Audio Playback Engine (major milestone)

- [ ] 5.1 Wire `just_audio` + `audio_service` for streaming playback directly from the server.
- [ ] 5.2 Build the mini-player (persistent bottom bar) and full-screen "Now Playing" screen.
- [ ] 5.3 Background playback: keep audio alive when app is backgrounded/screen locked.
- [ ] 5.4 Lock-screen / notification media controls (play/pause/skip) on both platforms.
- [ ] 5.5 Chapter navigation, skip-forward/back intervals, playback speed control.
- [ ] 5.6 Sleep timer.
- [ ] 5.7 Bookmarks within a book.
- [ ] 5.8 Sync playback progress back to the server (session reporting) so progress matches across devices.
- [ ] 5.9 Volume-button skip (matches audiobookshelf-app's volume-button-skip feature) — optional nice-to-have.

> 🤖 **Android checkpoint:** verify background playback + lock-screen controls survive screen-off, app-switch, and phone-lock on real hardware — this is the feature most likely to silently break outside a debugger.
>
> 🍎 **Xcode checkpoint (major landmark):** streaming audio in the background has real iOS-specific requirements (Background Modes → Audio capability, `audio_service`'s iOS setup, silent-mode behavior). Build and run in Xcode now — this is the first point where iOS entitlements/config actually matter, not just Dart code.

---

## Phase 6 — Offline Downloads & Local Library (major milestone)

- [ ] 6.1 "Download" action on a book/podcast episode → background download of audio files to local storage.
- [ ] 6.2 Local library data model distinguishing "server item" vs "downloaded local item" (mirrors `LocalLibraryItem` in the reference app).
- [ ] 6.3 Downloads screen: in-progress downloads with progress bars, completed downloads list, delete/manage storage.
- [ ] 6.4 Offline playback: play a downloaded book with zero network connection.
- [ ] 6.5 Sync local playback progress back to the server once connectivity returns (queue + retry).
- [ ] 6.6 Storage management: show space used, allow bulk-delete, warn on low device storage.

> 🤖 **Android checkpoint:** download a full audiobook on-device, kill the app mid-download to confirm resumability, then go offline (airplane mode) and play the downloaded file end-to-end.
>
> 🍎 **Xcode checkpoint (major landmark):** iOS background download/session behavior and local file storage sandboxing differ meaningfully from Android. Verify downloads survive backgrounding and offline playback works identically on a real iPhone/Simulator.

---

## Phase 7 — Podcasts

- [ ] 7.1 Podcast library view (separate from audiobooks, per Audiobookshelf's model).
- [ ] 7.2 Episode list per podcast, unplayed/played state.
- [ ] 7.3 "Add podcast" flow (subscribe via server) matching `add-podcast` in the reference app.
- [ ] 7.4 Episode download + offline playback (reuses Phase 6 download engine).
- [ ] 7.5 New-episode indicators / refresh.

> 🤖 **Android checkpoint:** subscribe to a podcast, download an episode, confirm it behaves the same as an audiobook through the shared playback/download engine (no special-cased bugs).

---

## Phase 8 — E-Books & Comics

- [ ] 8.1 EPUB reader screen (`epub_view`): pagination, font-size/theme controls, reading-position sync to server.
- [ ] 8.2 PDF reader screen.
- [ ] 8.3 Comic archive (CBZ/CBR) reader using the `archive` package for extraction + a page-viewer.
- [ ] 8.4 Unify "continue reading" progress alongside "continue listening" on the home shell.

> 🤖 **Android checkpoint:** read an EPUB and a CBZ end-to-end on-device, confirm reading position persists and syncs.

---

## Phase 9 — Account, Settings, Stats, Polish

- [ ] 9.1 Account screen (user info, logout, switch server).
- [ ] 9.2 Full Settings screen: playback defaults, download quality/behavior, appearance (skin switcher from Phase 2), notifications.
- [ ] 9.3 Listening stats screen (time listened, streaks, per-book stats).
- [ ] 9.4 Debug/logs screen for troubleshooting server connectivity issues (mirrors the reference app's `logs.vue` — genuinely useful for a self-hosted client).
- [ ] 9.5 Real app icon + splash screen (replace Phase 1 placeholders) in both skin styles if you want the icon itself to reflect the chosen skin.
- [ ] 9.6 Accessibility pass: font scaling, screen-reader labels, contrast check on the glass skin (translucent surfaces are an accessibility risk — verify text contrast over blur).
- [ ] 9.7 Empty-states and error-states polish across every screen (no server, empty library, failed download, etc.).

> 🤖 **Android checkpoint:** full app walkthrough — every screen, both skins, real server, real device.

---

## Phase 10 — Stretch Goals (optional, do only if core is solid)

- [ ] 10.1 Chromecast/casting support (`flutter_chrome_cast` or similar) — reference app supports this via `CastManager`/`CastPlayer`.
- [ ] 10.2 Widget/lock-screen glanceable playback widget.
- [ ] 10.3 Tablet/foldable responsive layout.
- [ ] 10.4 Additional skins beyond the two initial ones (community-style theming).

---

## Phase 11 — Release Prep

- [ ] 11.1 Set up the GitHub Actions macOS-runner workflow (discussed earlier) to build the iOS side automatically on push, even without daily Mac access.
- [ ] 11.2 App Store Connect + Google Play Console listings, screenshots per skin.
- [ ] 11.3 Versioning/changelog convention.
- [ ] 11.4 Beta distribution: TestFlight (iOS) + internal testing track (Android).

> 🍎 **Xcode checkpoint (final landmark):** full release-configuration build (signing, App Store archive) before submitting to TestFlight.

---

## Working Notes

- Treat Phases 5 and 6 as the two true "hard" milestones — background audio and offline downloads are where platform differences bite. Everything before that (Phases 0–4) is close to write-once-run-anywhere in Flutter.
- Test on Android continuously (fast iteration, no Mac trip required); reserve Xcode sessions for the milestones marked above rather than every single change, to match your Mac availability.
- Keep this file updated by checking off items as you go — it doubles as a changelog of what's actually been built.
