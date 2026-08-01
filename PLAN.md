# Steeped — Build Plan

A Flutter (single codebase, Android + iOS) client for a self-hosted **Audiobookshelf** server, aiming for
**full feature parity** with the official [audiobookshelf-app](https://github.com/advplyr/audiobookshelf-app)
(server connection, streaming, downloads, on-device local media, podcasts, e-books, Android Auto, casting, etc.)
but with a custom design system: a **glass/modern** look and a **user-selectable "skin"**
(e.g. a literal wooden-bookshelf skin vs. a frosted-glass modern skin) — built out once core functionality
is solid, in Milestone 3.

Reference material already on this machine:
- `~/Code/audiobookshelf-app` — official client source (Nuxt/Capacitor). Feature/behavior reference, not code to port — we rebuild natively in Dart. The full feature surface below was derived from its `strings/en-us.json`, `pages/`, `store/`, and native Kotlin/Swift plugins.
- `~/Code/audiobookshelf` — the server source, for confirming API response shapes.
- Official API docs: https://api.audiobookshelf.org

> This plan was cross-checked against the **server `readme.md`**, the **app `readme.md`**, and the app's actual
> source (strings, pages, native plugins). Every client-facing feature found is mapped to a phase in the
> **[Feature Parity Checklist](#feature-parity-checklist)** at the bottom — use that section to confirm nothing was dropped.

---

## Milestones

The build is organized into 5 milestones — this is the **delivery order**. Phase numbers (0–12) are stable
IDs used throughout this doc (the checklist below, cross-references like "reuses Phase 6 engine") and do
**not** change even though their physical read order in this file now follows milestone order rather than
strict numeric order — Phase 2 is the one phase that moved (from early to Milestone 3).

| Milestone | Focus | Phases |
|---|---|---|
| **1 — Core Streaming** | Connect to a server, authenticate, browse a library, stream a book, with a basic (single, default-themed) UI. | 0, 1, 3, 4, 5 |
| **2 — Content, Offline & Downloads** | Offline downloads + on-device local media, podcasts, e-books/comics, and the account/settings/stats/RSS surface around them. | 6, 7, 8, 9 |
| **3 — UI Customization & Skins** | The full design-system/skin engine (glass-modern + bookshelf skins, live switcher) retrofitted across the screens built in Milestones 1–2. | 2 |
| **4 — Car Integration** | Android Auto & CarPlay, browsing everything shipped so far (including podcasts/e-books from Milestone 2). | 10 |
| **5 — Stretch Goals & Release Prep** | Optional power-user features, then signing/store listings/beta distribution. | 11, 12 |

---

## Testing Cadence (read this first)

Two separate rhythms, because you develop on Linux and have a Mac nearby (not primary):

- 🤖 **Android — semi-frequent, on your plugged-in device.** Test at the **end of every phase**, and any time a
  sub-item touches native behavior (playback, downloads, notifications). This is your fast inner loop — no Mac
  trip required. Every phase below ends with an 🤖 checkpoint.
- 🍎 **iOS / Xcode — large milestones only, on the Mac.** Reserve Mac sessions for the points where iOS genuinely
  diverges from Android (background audio entitlements, download/session sandboxing, file storage, release
  signing). These are called out inline as 🍎 checkpoints and summarized here (still in phase-number order,
  which remains chronological — Phase 2's move doesn't cross any of these):

  | # | When | Why it's an iOS milestone |
  |---|------|---------------------------|
  | 🍎 **Smoke** | After Phase 1 | Confirm the iOS shell **builds & launches at all** (`flutter run` on Simulator) before stacking features on it. Cheap insurance against late-discovered build breakage. |
  | 🍎 **1** | End of Phase 3 | First real device/network behavior: server connection + secure token storage on iOS (Keychain differs from Android). |
  | 🍎 **2 (major)** | End of Phase 5 | **Background audio** — iOS Background Modes → Audio entitlement, `audio_service` iOS setup, silent-switch behavior, lock-screen/Control-Center controls (which also surface in CarPlay Now-Playing for free). Biggest platform-divergence point. |
  | 🍎 **3 (major)** | End of Phase 6 | **Offline downloads & local file storage** — iOS background URLSession semantics + app-sandbox file paths differ substantially from Android. |
  | 🍎 **4** | End of Phase 8 | E-reader rendering + on-device file access parity (EPUB/PDF/CBZ) on iOS. |
  | 🍎 **5 (major)** | End of Phase 10 | **CarPlay** — full browse hierarchy + Now-Playing in the Xcode CarPlay Simulator; requires the Apple CarPlay audio entitlement to be provisioned. |
  | 🍎 **6 (final)** | Phase 12 | Release-config archive: signing, entitlements, App Store build → TestFlight. |

  Everything else (UI, theming, library browsing, settings, stats) is effectively write-once-run-anywhere in
  Flutter and does **not** need a dedicated Mac trip — it'll be validated during these milestones.

Legend used inline below:
- 🤖 **Android checkpoint** — build/run on your plugged-in Android device.
- 🍎 **Xcode checkpoint** — open in Xcode on the Mac, build/run on Simulator or device.

---

## Milestone 1 — Core Streaming (Connect, Authenticate, Stream, Basic UI)

### Phase 0 — Tech Stack Decisions

- [x] 0.1 State management: **Riverpod** — chosen for async server/streaming state over Bloc.
- [x] 0.2 Navigation: **go_router** — declarative routing + deep links (open-a-book links later).
- [x] 0.3 Networking: **dio** — interceptors for auth headers/token refresh.
- [x] 0.4 Real-time: **socket_io_client** — corrected during Phase 3: the Audiobookshelf server runs **socket.io v4**, not a raw websocket (confirmed against `~/Code/audiobookshelf/server/SocketAuthority.js` and the reference app's `socket.io-client` dependency). A raw `web_socket_channel` can't speak socket.io's framing, so that package was swapped out. Needed for progress/library sync and metered-connection awareness.
- [x] 0.5 Local database: **drift** (SQLite) — chosen over Isar: the data (libraries/series/collections/playlists + filter/sort) is genuinely relational, Drift has a real migration system for a schema that will evolve across milestones, a longer/more predictable maintenance track record, and plain-SQLite files are easy to debug directly (open the `.db` file in any SQLite browser). Neither engine is in the actual audio-streaming path (that's `just_audio`/`dio`), so this decision wasn't made on streaming performance.
- [x] 0.6 Secure storage: **flutter_secure_storage** — server URL + auth token (Keychain on iOS, Keystore on Android).
- [x] 0.7 Audio: **just_audio** + **audio_service** — background playback, lock-screen/notification controls, Android Auto & CarPlay Now-Playing.
- [x] 0.8 Downloads: **background_downloader** — resumable background downloads with queue.
- [x] 0.9 E-books: `epub_view`/`epubx` (EPUB), `pdfx`/`syncfusion_flutter_pdfviewer` (PDF), `archive` (CBZ/CBR).
- [x] 0.10 Casting: **Android-only**, deferred to Milestone 5 (Phase 11) — pick a Cast plugin (e.g. `flutter_chrome_cast`) when that phase starts.
- [x] 0.11 Connectivity: **connectivity_plus** — detect metered wifi/cellular for the cellular-data controls.
- [x] 0.12 Localization: **flutter_localizations** + `intl` / ARB files — the reference app ships **40 languages**; architect for i18n from day one even if you launch with English.
- [x] 0.13 Car integrations: **`audio_service`** already backs **Android Auto** (media-browser). For **CarPlay**, **`flutter_carplay`** (or native Swift CarPlay templates). **Action item for you:** request the CarPlay audio-app entitlement (`com.apple.developer.carplay-audio`) from Apple now via your Apple Developer account — approval gates the feature and can take time, even though it's implemented late (Milestone 4). This is an Apple Developer Program action only you can take.
- [x] 0.14 Decisions written into `README.md` (see its Tech Stack section).

> 🤖 No checkpoint — decisions only, no code. Packages get added to `pubspec.yaml` in Phase 1.2.

---

### Phase 1 — Project Skeleton & Architecture

- [x] 1.1 Folder structure: `lib/core` (theme, network, storage, router), `lib/features/<feature>` (auth, library, player, downloads, localmedia, ebook, podcasts, settings, stats), `lib/models`, `lib/widgets`.
- [x] 1.2 Add chosen packages to `pubspec.yaml`; `flutter pub get`. Only packages Milestone 1 actually needs were added now (state mgmt, nav, networking, websocket, drift, secure storage, audio engine, connectivity, i18n) — downloads/ebook/car/cast packages are deferred to their own milestones rather than added unused.
- [x] 1.3 Riverpod `ProviderScope` at app root (`lib/main.dart`).
- [x] 1.4 `go_router` with placeholder routes: splash, connect-to-server, login, home shell, settings (`lib/core/router/app_router.dart`).
- [x] 1.5 i18n scaffolding: `l10n.yaml` + `lib/l10n/app_en.arb`, `flutter gen-l10n` wired into `MaterialApp.router`.
- [x] 1.6 Lint rules (`flutter_lints`) + `analysis_options.yaml` — already present from project scaffolding, confirmed using the recommended set.
- [x] 1.7 `flutter_launcher_icons` + `flutter_native_splash` added as dev dependencies, ready for Phase 9 once real artwork exists. No fake icon was generated — the `flutter create` defaults remain as the placeholder until then.
- [x] 1.8 **Minimal theme baseline**: `lib/core/theme/app_theme.dart` — `AppSpacing`/`AppRadii` design tokens as `ThemeExtension`s, one default coffee-toned dark `ColorScheme`. No skin switching yet — deferred to Milestone 3 (Phase 2).

> 🤖 **Android checkpoint: verified 2026-07-31** on a Pixel 8 Pro (Android 17) over USB — builds, installs, and launches cleanly; splash screen renders with the Phase 1.8 theme (dark coffee-toned background, themed spinner), no crashes in logcat. Route navigation between the other placeholder screens isn't meaningfully testable yet since Phase 3 hasn't wired real navigation logic. (See the `steeped-android-build-env` memory for two one-time environment fixes this machine needed: a missing JDK devel package, and oversized default Gradle/Kotlin heap settings.)
>
> 🍎 **Xcode smoke checkpoint:** open on the Mac and confirm the iOS shell **builds and launches on the Simulator** at all. Do this now, before features stack up, so any iOS toolchain/signing issue surfaces early and cheap.

---

### Phase 3 — Server Connection & Authentication

- [x] 3.1 "Connect to Server" screen: enter URL, validate reachability against a known Audiobookshelf endpoint. Real `GET /status` check; endpoint shapes confirmed against `~/Code/audiobookshelf` source (not guessed).
- [x] 3.2 Login (username/password) → auth-token exchange. Handles the v2.26.0+ JWT flow (`accessToken`/`refreshToken`) with fallback to the legacy static `token` for older servers — see `AuthUser.effectiveToken`.
- [ ] 3.3 **Multiple saved servers/accounts** with a "Switch Server/User" switcher. **Deferred** — a single active session is sufficient for Milestone 1's stated goal (connect, authenticate, stream); `SessionStorage`'s schema doesn't preclude adding this later, but the multi-server switcher UI + a drift `ServerProfiles` table are real additional scope not built yet.
- [x] 3.4 Store token + URL in secure storage; `dio` interceptor attaches auth header, handles 401 → token refresh → re-login. `AuthInterceptor` does a single refresh+retry via `POST /auth/refresh`, then forces logout on failure — mirrors the reference app's `nativeHttp.js`.
- [x] 3.5 Persisted "current user/session" provider (`SessionController`), including the user's **server-side permissions** (`UserPermissions`, with `canAccessLibrary`/`canAccessLibraryItemWithTags` helpers ported from `User.js`).
- [x] 3.6 **Websocket connection** to the server for live updates; surface connection status. Uses **socket.io v4** (`socket_io_client`), not a raw websocket — see the 0.4 correction above. Connects, emits `auth`, and a `SocketConnectionStatus` (disconnected/connecting/connected/authenticated/authFailed) is shown live in the home shell app bar ("Live" badge). Metered/unmetered wifi/cellular labeling is not yet implemented (needs `connectivity_plus` wiring — small follow-up, not done in this pass).
- [x] 3.7 Offline/unreachable-server states handled gracefully: connect-server and login screens show inline error messages for timeouts, connection errors, bad responses, and wrong credentials rather than crashing or hanging.
- [ ] 3.8 "Mask server address" privacy toggle (minor parity item). **Deferred to Phase 9** — there's no real Settings screen to host the toggle yet (Phase 1's `SettingsScreen` is still a placeholder); not worth a one-off UI for it now.

> 🤖 **Android checkpoint: verified 2026-07-31** on the Pixel 8 Pro against evan's real Audiobookshelf server — connected, logged in as `evan`, session persisted through the app's Riverpod state, and the home shell shows a live "Live" socket status badge confirming the socket.io auth handshake succeeded. Full real-server round trip, not just a mocked/local check.
>
> 🍎 **Xcode checkpoint 1 (still open):** verify server connect + **secure token storage on iOS (Keychain)** and websocket connectivity on a real network — Keychain semantics differ from Android Keystore. Not yet done — needs the Mac.

---

### Phase 4 — Library Browsing

- [x] 4.1 Data models: `Library`, `LibraryItem` (minified, book/podcast flattened for card UI), `LibraryItemDetail` (expanded: `AuthorRef`, `SeriesRef`, `BookChapter`), `PersonalizedShelf`, `MediaProgress` — matching real API shapes confirmed against `~/Code/audiobookshelf` source (not guessed). `Collection`/`Playlist` models not yet added — see 4.5.
- [x] 4.2 Fetch/list libraries (`GET /api/libraries`); library switcher (popup menu in the home app bar, only shown when >1 library exists).
- [x] 4.3 Home shell rows via `GET /api/libraries/:id/personalized` — rendered **generically by shelf type** (item/series/authors) rather than hardcoding each row, so whatever shelves the server returns (Continue Listening, Recently Added, Discover, Listen Again, etc.) just show up. Verified live: 4 shelves rendered correctly against evan's real library.
- [x] 4.4 Full library view (`/library/:id`): paginated grid (`GET /api/libraries/:id/items`), infinite-scroll load-more, single default theme per Phase 1.8. Verified live: 60 real items, covers + titles + authors.
- [ ] 4.5 Authors, Series (with **collapse series**), Collections, Playlists browse screens. **Deferred** — personalized shelves already surface a slice of this (Recent Series / Newest Authors rows exist and render, just as non-interactive cards for now), but dedicated browse screens + `Collection`/`Playlist` models are real additional scope not built in this pass.
- [ ] 4.6 **Filtering & Sorting**. **Deferred** — the `/items` endpoint already supports `sort`/`desc`/`filter` query params server-side, so this is a UI-only follow-up (a sort menu + filter sheet) whenever it's prioritized, not a data-layer gap.
- [ ] 4.7 Search. **Deferred** — the real search endpoint's response is grouped by category (book/series/authors/narrators/tags, differently shaped per library media type) and needs meaningfully distinct UI per group; genuine additional scope, not built in this pass.
- [x] 4.8 Item detail screen (`/item/:id`, `GET /api/items/:id?expanded=1&include=progress`): cover, subtitle, authors, narrators, series, genres, description, duration, chapter count, published year, progress bar. "Play"/"Read" are stubs (real actions land in Phase 5 / Milestone 2); "Download"/"Add to Playlist" not yet present (Milestone 2 / deferred 4.5). Verified live against a real item ("Dune") with real metadata.
- [x] 4.9 Cover image caching via `cached_network_image`, shared `CoverImage` widget used everywhere a cover renders. Cover URLs use the `?token=` query-param auth path (not the header) since image loads don't go through `dioProvider`'s interceptor.

> 🤖 **Android checkpoint: verified 2026-07-31** on the Pixel 8 Pro against evan's real Audiobookshelf server — library switcher, personalized shelves (Continue Listening/Recently Added/Discover/Listen Again), full 60-item grid with infinite scroll, and item detail all confirmed working with real data and real cover art, no crashes.

---

### Phase 5 — Audio Playback Engine (major milestone)

- [x] 5.1 `just_audio` + `audio_service` streaming from the server. **Direct play only** — the `/play` session endpoint and its format-compatibility negotiation are deliberately skipped (research confirmed `GET /api/items/:id?expanded=1` already returns the same `media.tracks[]`/`contentUrl`s the session endpoint would, with no session bookkeeping needed); transcode fallback for incompatible formats is **not implemented**. Multi-file books use a gapless multi-source `just_audio` playlist (one child per track, matching the server's un-concatenated `Book.getTracklist()` model) rather than one continuous stream.
- [x] 5.2 Mini-player (persistent bottom bar, shown on home/library/detail) + full-screen "Now Playing" (`/now-playing`).
- [x] 5.3 Background playback via `audio_service`'s Android foreground service — confirmed alive with active audio decoding after backgrounding.
- [x] 5.4 Lock-screen / notification media controls — confirmed via the real system media-control card (title/artist, play-pause, seek, rewind/fast-forward). "Allow position seeking on media controls" toggle not built (no Settings screen yet — Milestone 2).
- [x] 5.5 Chapters + chapter navigation (tap-to-seek list, current chapter highlighted) + jump forward/back — **fixed 30s interval**, not yet customizable (Settings, Phase 9).
- [x] 5.6 Playback speed (0.75x–2x dropdown). "Scale elapsed time by speed" display option not built.
- [x] 5.7 **Sleep timer.** Built in Phase 9.3 alongside the rest of the Settings taxonomy — a real, working manual-duration timer (5/15/30/45/60 min + a configurable default, countdown, auto-pause on expiry, cancel), accessible from Now Playing. Verified live: started a timer (icon fills), cancelled it (icon reverts), playback unaffected throughout. End-of-chapter, shake-to-reset, fade-out, and chime remain deferred — the basic manual timer covers the core use case.
- [ ] 5.8 Bookmarks. **Deferred** — separate feature, not built in this pass.
- [x] 5.9 Progress sync — sessionless `PATCH /api/me/progress/:id` every 15s while playing + on pause (research found this simpler than the session-based `/api/session/:id/sync` path, which requires calling `/play` first). No metered-connection throttling and no dedicated "sync failed" UI (best-effort, silently retries next tick) — both deferred.
  - **Bug found + fixed 2026-07-31**: the sync timer was started/stopped only by `PlaybackController`'s own `pause()`/`resume()` methods — but a hardware media button, the notification's pause action, or a headset button call `SteepedAudioHandler.pause()` directly (that's the point of exposing a MediaSession), bypassing those methods entirely. The timer kept running after a hardware pause, and once connectivity came back it synced a stale (near-zero) position to the real server, silently overwriting real progress. Fixed by driving the timer off `SteepedAudioHandler.playbackState`'s actual `playing` flag instead — it now reacts correctly regardless of what paused it. **This corrupted real listening progress on evan's server for one book during testing** (`currentTime` reset while the `progress` fraction stayed intact); repaired by recomputing `currentTime` from the still-correct fraction and writing it back. Fixed and verified: a downloaded book now resumes at the right position (confirmed 4:58:06 of 12:38:05, matching 39%).
- [x] 5.10 Mark as **Finished / Not Finished** (overflow menu on Now Playing) — same progress endpoint, `isFinished` flag. Discard/reset progress not built as a separate action.
- [ ] 5.11 Volume key navigation. **Deferred**.
- [x] 5.12 **Media-session foundation** — real `MediaSession` confirmed via the system media-control card and notification's `android.mediaSession` token; this is the substrate Milestone 4's CarPlay/Android Auto browse trees will build on.
- [ ] 5.13 Lock/unlock player UI, keep-screen-awake toggle, MP3 index-seeking. **Deferred** — advanced/power-user items.

> 🤖 **Android checkpoint: verified 2026-07-31** on the Pixel 8 Pro against evan's real Audiobookshelf server — played "The Tower of the Swallow" (resumed correctly at 14:42:32 of 16:24:11, matching its 89% server-side progress) and "Heir to the Empire" (started at 0:00). Confirmed via real device signals, not just UI: the system media-control notification (title/artist/transport/seek), an active `MediaSession` token, continued AAC decoding after backgrounding, and accurate chapter-boundary highlighting during playback. Also fixed along the way: `permission_handler` needed `compileSdk`/`targetSdk` bumped to 37 in `android/app/build.gradle.kts` (Flutter's bundled default hadn't caught up).
>
> 🍎 **Xcode checkpoint 2 (major landmark):** iOS **Background Modes → Audio** entitlement, `audio_service` iOS config, silent-switch behavior, Control-Center/lock-screen controls (these auto-surface in CarPlay's Now-Playing; the full CarPlay browse experience comes in Milestone 4). Not yet done — needs the Mac.

---

## Milestone 2 — Content, Offline & Downloads

### Phase 6 — Offline Downloads & On-Device Local Media (major milestone)

Two distinct capabilities the reference app has: (a) **downloading server items** for offline use, and
(b) **importing/scanning on-device folders** of media that never came from the server ("Local Media").

- [x] 6.1 "Download" action on a book → background download via `background_downloader` (one task per audio track + cover, grouped by item id). Podcast episodes not covered (podcasts are Milestone 2/Phase 7, not built yet). Server download-permission isn't checked client-side yet (minor gap — the server would reject an unauthorized download anyway, but the client doesn't pre-emptively hide the button).
- [x] 6.2 **Series download**. **Built 2026-08-01** without needing full series browsing (4.5, still deferred) — reuses the existing `/api/libraries/:id/items` endpoint's `filter=series.<base64(id)>` query param (confirmed against `~/Code/audiobookshelf/server/utils/queries/libraryFilters.js`) rather than a dedicated series endpoint. A "Download series: <name>" action appears on item detail for any book with series metadata; queues one download per not-yet-downloaded book in that series. Verified live: downloaded all 3 books of the Thrawn Trilogy from one tap, confirmed all appeared in the Downloads queue and finished (1.5GB total).
- [x] 6.3 **Download location**: Internal App Storage only (`BaseDirectory.applicationDocuments`, via `path_provider`) — no shared-storage/SD option built. This sidesteps the Android-10-and-below internal-only caveat entirely rather than handling it, which is a reasonable simplification: the plan's own note is that internal-only is required behavior on older Android anyway, and app-scoped storage is simplest and needs no extra permissions.
- [x] 6.4 Local library model: drift `DownloadedItems`/`DownloadedTracks` tables — distinguishes downloaded-local from server-only. **`buildOfflineItemDetail` reconstructs a fully playable item from local rows alone (title, authors, chapters, tracks) — zero network call**, which is what makes 6.6 genuinely offline rather than "streams from a cache." "Imported local-media item" (on-device files never from the server) doesn't apply — that's 6.8, deferred. "Linked to different server/user" edge case not handled (single-session app currently — see 3.3 deferral).
- [x] 6.5 Downloads screen (`/downloads`): completed list with cover/title/delete, live progress bars for in-progress downloads. No explicit in-progress-vs-completed section split (list just shows both) and no "clear queue" action — `background_downloader` manages queue ordering internally, nothing in the UI to clear.
- [x] 6.6 **Offline playback with zero connectivity — verified for real**, not just implemented: downloaded a book, force-disabled wifi + cellular data (confirmed via `ping` failing with "Network is unreachable"), and played it from the already-running app — audio decoded, position advanced, chapter highlighting tracked correctly, all from local files + locally-cached metadata. **Cold-start-while-offline gap, found 2026-07-31, fixed 2026-08-01**: `SessionController`'s bootstrap (Phase 3) treated a network-unreachable startup token refresh identically to a genuine 401 rejection, clearing the whole session either way — locking a fully offline cold start out of downloaded content and forcing a real re-login once connectivity returned for what was really just a network blip. Fixed: only a real `DioExceptionType.badResponse` (the server actually rejecting the refresh token) logs the user out now; any other failure falls back to the cached session, same as the pre-existing legacy-token path. Verified live: force-stopped the app mid-offline-playback, cold-relaunched still offline — session stayed authenticated ("Offline" badge, not kicked to login) and the downloaded book kept playing; confirmed via the Logs screen showing "Startup token refresh unreachable, using cached session." **Second bug found during the original verification, also fixed 2026-07-31**: this offline test session's leftover sync timer (see 5.9's entry above) is what corrupted the real server progress — the two issues were discovered together when the user noticed a downloaded book wasn't resuming where expected. See 5.9 for the fix and repair.
- [x] 6.7 Sync local progress back to server on reconnect. **Real durable queue built 2026-08-01**: a failed progress sync now persists to a `PendingProgressSyncs` drift table (one row per item/episode, later failures overwrite earlier ones) instead of only retrying on the next 15s tick while the app happens to stay open. A connectivity-change listener plus an app-start check flush the queue once a real connection returns — durable across app restarts, not just within a session. A real server rejection (bad response, not a connectivity error) drops the row rather than retrying forever. Verified live: played a downloaded book, cut all connectivity, confirmed a sync queued (read the drift table directly), force-stopped and cold-relaunched the app *still offline* (row survived the restart, even picked up a later position via the upsert), then restored connectivity and confirmed the queued sync flushed automatically with no "dropped" log entry.
  - **Earlier verification, 2026-07-31** (requested by evan, before the durable-queue rework): played a downloaded book, went offline mid-playback, let it advance ~70s offline, restored connectivity *without pausing*, and confirmed via a raw server response that `currentTime` had correctly advanced to the new position within one sync tick — reconnect-while-playing does upload. Also confirmed: a downloaded item is preferred over streaming *whenever it exists*, not just when offline (`playItem()` checks `isDownloaded` unconditionally, no online/offline branch) — so playing a downloaded book while online still uses the local file and still uploads progress normally.
  - **Display bug found + fixed during that verification**: the server's `progress` fraction field is *not* recomputed by our sessionless progress PATCH — only `currentTime`/`duration` are (confirmed: after a real sync, `currentTime` had advanced but `progress` stayed at its old value). The item detail screen's "% complete" was reading that stale fraction directly from the server. Fixed to compute the displayed percentage from `currentTime / duration` client-side instead, matching what's actually used to resume playback. This was a display-only bug — actual resume position was never affected by it.
- [x] 6.8 **Local Media folders** (on-device import, no server involved). **Built 2026-08-01, simplified to single-file import rather than a whole-folder scan**: Android scoped storage means arbitrary folder access needs a persisted SAF tree URI whose path resolution is inconsistent across OEMs, while picking individual files via `flutter_file_dialog` resolves to a real, reliable path. Covers the actual use case (import audio that never lived on the server) without that reliability risk — tap "Import" once per file, repeat to add more. Chose `flutter_file_dialog` over `file_picker`: every `file_picker` version compatible with our `wakelock_plus` constraint is a pre-release, because `file_picker`'s Windows plugin pulls a `win32` version `wakelock_plus` conflicts with (irrelevant to this Android/iOS-only app, but pub's resolver still enforces it). New `LocalMediaItems` drift table tracks imported files with purely local progress — no server item id exists, so `PlaybackController`'s sync paths skip the network entirely for these via a new `isLocalOnly` flag on `LibraryItemDetail`. Verified live: imported a real WAV file via the system file picker, played it through the full Now Playing UI, confirmed local-only progress persisted with zero log entries (no network sync attempted), then deleted it and confirmed the file was actually removed from disk.
- [x] 6.9 **Cellular-data controls**. Built in Phase 9.3 once a real Settings screen existed to host them — separate stream/download toggles, enforced via `connectivity_plus` in `PlaybackController`/`DownloadController` before each network action starts, with a shared snackbar (`cellularBlockNoticeProvider`, surfaced through `MiniPlayer`) when blocked. Not verified on-device with a real cellular-only connection (would need airplane mode + manually re-enabling mobile data on the test device) — the connectivity-detection logic itself mirrors the same `connectivity_plus` API already relied on elsewhere.
- [x] 6.10 **Storage management**. **Built 2026-08-01**: total/per-item download sizes, a low-storage warning against real free device space, and bulk-delete on the Downloads screen. Free space comes from a small native `StatFs` platform channel (`DeviceStorage`, Android-only for now) rather than a pub dependency — avoids the `image`-package version conflict this project already hit once (Phase 8.1's pubspec note). Verified live: downloaded a real 292MB book, confirmed "Downloads use 292 MB · 12 GB free" and the per-item size label, and exercised the delete-all confirmation dialog on a 4-item batch (1.5GB).

> 🤖 **Android checkpoint: verified 2026-07-31** on the Pixel 8 Pro against evan's real Audiobookshelf server — downloaded "The Exquisite Torment of Loving Your Enemy" (12h38m, 38 chapters) over WiFi, watched live progress (0%→44%→70%→93%→Downloaded), then genuinely cut all connectivity (wifi + cellular data disabled, `ping` confirmed unreachable) and played it successfully with real-time position/chapter tracking. Downloads screen confirmed showing the completed item with local cover art. Did not test kill-app-mid-download resume.
>
> 🤖 **Android checkpoint 2: verified 2026-08-01** — closed out every item deferred from the first pass (6.2, 6.7, 6.8, 6.10) plus the cold-start-offline gap from 6.6, all driven live over adb per-item as detailed above. Phase 6 is now fully complete, no open items.
>
> 🍎 **Xcode checkpoint 3 (major landmark):** iOS **background URLSession** download behavior + **app-sandbox file paths** differ substantially. Not yet done — needs the Mac.

---

### Phase 7 — Podcasts

- [x] 7.1 Podcast library view (separate media type). Podcast items already list generically in the home shelves + full-library grid (the `LibraryItem` book/podcast flattening from 4.1); Phase 7 adds the podcast **detail** screen — tapping a podcast now renders its episodes instead of the old "coming in Phase 7" placeholder (`PodcastDetailBody`, branched from `ItemDetailScreen` on `isPodcast`). A "Latest Episodes" entry appears on the home of any podcast-media-type library (7.6).
- [x] 7.2 Episode list per podcast; played/unplayed/incomplete state; count. Episodes come from the expanded item's `media.episodes[]` (`PodcastEpisode` model), sorted newest-first by `publishedAt`. Per-episode progress isn't inlined on the item response, so it's merged in from the user's `mediaProgress` (`GET /api/me`, filtered to this podcast) — a check for finished, a play-circle + "N% played" for in-progress, an empty circle for unplayed. Header shows "N episodes · M incomplete".
- [ ] 7.3 **Add podcast** flow (subscribe via server; search term or RSS URL) — "Podcast created" success/fail toasts. **Deferred — confirmed permission-blocked, not source-blocked.** The server source (`~/Code/audiobookshelf`) is on this machine after all, and `PodcastController.create` (`POST /api/podcasts`) requires `req.user.isAdminOrUp` directly — evan's account is `type: user` (non-admin), so this would 403 regardless. The subscribe *reads* (term search, RSS-feed preview) remain safe/buildable, but the create action itself genuinely cannot be exercised against evan's real server. Same reasoning defers 7.4.
- [ ] 7.4 **Auto-download episodes** setting per podcast. **Deferred — confirmed permission-blocked**: setting it is a `PATCH` on the podcast media, gated behind `req.user.canUpdate` server-side (`PodcastController.middleware`). Verified live 2026-08-01 via a new Account-screen permission display: evan's account has **Updates allowed: ✗**, so this would 403 too.
- [x] 7.5 Episode download + offline (reuses Phase 6 engine); delete local episode. **Device download + offline playback + local delete: done.** Reuses the Phase 6 `background_downloader` path unchanged, keyed by a composite `podcastId::episodeId` `downloadId` (see `LibraryItemDetail.downloadId`) so episodes of one podcast don't collide on the `DownloadedItems` primary key — **no drift schema change needed**, the id is just a string, and `buildOfflineItemDetail` splits it back to reconstruct the episode fully offline. Per-episode download button (download / progress ring / downloaded-delete) on both the podcast detail and Latest-Episodes screens. **`delete-episode-from-server` deferred — confirmed permission-blocked**: `PodcastController.removeEpisode` (DELETE) is gated behind `req.user.canDelete`; the same 2026-08-01 Account-screen check found evan's account has **Deletes allowed: ✗**. Local delete is what a client normally needs regardless.
- [x] 7.6 Latest/newest-episodes feed (`GET /api/libraries/:id/recent-episodes`, `RecentEpisodesScreen`, reachable from a podcast library's home) with play + download per entry. **New-episode indicators and an explicit "next episode" action are not built** — minor parity items; the feed itself is the substance. Confirmed live: the endpoint returns `{ episodes: [...], limit, page }` (verified via temporary debug logging against evan's real server, then reverted) — matches what `RecentEpisode.tryFromJson` expects; evan's library only has one (very old, 2005) episode, so the feed legitimately returns `episodes: []`, not a parsing bug.

**Episode playback** rides the existing engine: `PlaybackController.playEpisode` loads the episode's single `audioTrack` as a one-track item (id kept as the parent podcast's, `episodeId` set) so cover + progress resolve correctly, and progress syncs to the two-segment `PATCH /api/me/progress/:libraryItemId/:episodeId` (added to `ProgressRepository`). A downloaded episode is preferred over streaming, exactly like books (6.6).

> 🤖 **Android checkpoint: verified 2026-07-31** on the Pixel 8 Pro against evan's real Audiobookshelf server (podcast library: "Living with Harry Potter," BBC Radio 4, 1 episode). Confirmed via adb (build → install → drive with `input tap` + `screencap`, not just launched): podcast detail renders the real episode list with correct date/duration/"Finished" state; downloaded the episode (~56MB real file + cover landed on disk under the composite `podcastId::episodeId` path); played it back **fully offline from the local file** — Now Playing showed real decoding and advancing position with working transport controls; deleted the local download and confirmed the file was actually removed from disk and the shared Downloads screen correctly dropped the entry with no orphan row, leaving the pre-existing book download untouched. The Latest Episodes feed's empty state was confirmed genuine (see 7.6 above), not a bug. Add-podcast (7.3), auto-download (7.4), and delete-from-server remain deliberately deferred.

---

### Phase 8 — E-Books & Comics

Reading material is served by the *same* generic `GET /api/items/:id/file/:ino` endpoint audio tracks use
(confirmed live against evan's real server for both a 44MB EPUB and a 128MB CBZ — checked the raw response
byte count and ZIP magic bytes `PK\x03\x04` matched exactly). `EbookRepository` caches the file to app
storage on first "Read" tap (a plain one-shot cache, not the queued Phase 6/7 download engine — reading is
on-demand, not an explicit offline-save action). "eBooks" and "Comics" are both server `mediaType: 'book'`
libraries under the hood, differentiated only by `ebookFormat` on the item, not by library type.

- [x] 8.1 **EPUB reader** (`epub_view`): pagination (continuous scroll), table of contents (jump-to-chapter), reading-position sync to server. Confirmed live: `userMediaProgress.ebookLocation` (an EPUB CFI string) + `ebookProgress` (0..1 fraction) are separate fields from the audio `currentTime`/`progress` ones — `ProgressRepository.updateEbookProgress` added for this, PATCHing the same `/api/me/progress/:id` endpoint with the different body shape.
  - **Real crash found + fixed during on-device testing**: `epub_view` 3.2.0's built-in `<img>` handler does `document.Content!.Images![url]!.Content!` with no fallback — throws "Null check operator used on a null value" (blanking the *entire* reader body, no per-item error boundary) whenever an image `src` doesn't exactly match its naively-normalized key. Reproduced reliably on a real illustrated book via TOC navigation. Fixed with a custom `chapterBuilder` (`_safeChapterBuilder` in `epub_reader_screen.dart`) that tries several path-matching strategies before giving up and rendering nothing for that one image, instead of crashing the chapter. Verified fixed: the same TOC jump that crashed before now renders the real illustrations correctly.
- [x] 8.2 **Ereader settings**: font family (Sans/Serif), font scale, font boldness (bold toggle), line spacing, theme (Light/Dark/Black). Persisted locally via the existing `KeyValueEntries` drift table (first real use of that scaffolded-but-unused table) — these are device display prefs, not server-tracked. "Layout (Auto/Single page)" not built — `epub_view` is continuous-scroll only, no single-page mode to toggle.
- [x] 8.3 **PDF reader** (`pdfx`): paged view + page counter. No ereader text-styling (PDF is fixed-layout, matches reference app scope). Progress synced as page-number-as-string in the `ebookLocation` field (no CFI-equivalent concept for PDF) + page/pageCount as `ebookProgress`. **Not verified on-device** — evan's library has real EPUB and CBZ items but no confirmed PDF item was found to test against; built and `flutter analyze`-clean like the rest, but this is the one reader without a real-file checkpoint.
- [x] 8.4 **Comic archive (CBZ)** reader via `archive` extraction (off the UI isolate via `compute()` — confirmed necessary and working against a real 128MB/16-page CBZ) + `PageView` page viewer with natural filename sorting (`page2` before `page10`) and resume-from-saved-page. **CBR is not supported** — `archive` (pure Dart, no native deps) only decodes zip-family formats, and no maintained pure-Dart RAR decoder exists; `EbookFile.isSupported` is false for `.cbr` and the Read button surfaces a message instead of a broken reader.
  - **Real bug found + fixed during on-device testing**: page-swiping silently didn't work at all — an `InteractiveViewer` (added for pinch-zoom) claims every single-finger drag from the gesture arena via its internal `ScaleGestureRecognizer` *before* the parent `PageView` ever sees it. Setting `panEnabled: false` looked like the fix but isn't — it only suppresses the resulting pan translation, not the gesture claim itself (confirmed by reading `InteractiveViewer`'s source: the scale recognizer always wins the arena; `panEnabled` is checked afterward). Fixed by dropping `InteractiveViewer` entirely — reliable paging matters more than pinch-zoom for this pass. Verified fixed: swiped through multiple real pages of the 16-page CBZ, page counter advanced correctly each time.
- [ ] 8.5 Primary vs supplementary ebook handling. **Deferred** — evan's items only ever showed a single `media.ebookFile`, so the multi-file "primary vs supplementary" shape was never observed live to build against; setting it is also a server-mutating metadata action.
- [ ] 8.6 **Send Ebook to Device** (e.g. Kindle). **Deferred** — a server action gated on SMTP being configured server-side, not something a client blind-implements without confirming the request/response shape against server source (not on this machine, same reasoning as Phase 7.3's deferral).
- [x] 8.7 Unify "continue reading" alongside "continue listening". **Turned out to already work for free** — the personalized-shelves renderer (Phase 4.3) was already generic-by-shelf-type with no hardcoded shelf list, so the server's real "Continue Reading" shelf for the eBooks library rendered correctly with zero new code, confirmed live on evan's real eBooks library home.

> 🤖 **Android checkpoint: verified 2026-07-31** on the Pixel 8 Pro against evan's real server — driven live over adb (build → install → `input tap`/`screencap`), not just launched. Read a real 44MB illustrated EPUB ("Harry Potter — A History of Magic") end-to-end: table of contents, chapter jump, multiple real embedded illustrations rendering after the image-crash fix, reading settings (font/theme/size/spacing) applying live, and progress syncing (confirmed the item then appeared in the "Continue Reading" shelf). Read a real 128MB/16-page CBZ ("The Legend of Genji") end-to-end: resumed at the correct saved page (12/16, matching its prior "Finished" progress), paged forward through multiple pages correctly after the swipe-gesture fix, extraction ran off the UI thread with no jank. **PDF reader not verified on-device** (no confirmed PDF item in evan's library) — built and analyze-clean, same caveat treatment as Phase 7's unverified endpoint. 8.5/8.6 deliberately deferred, reasoning above.
>
> 🍎 **Xcode checkpoint 4:** confirm EPUB/PDF/CBZ rendering + on-device file access parity on iOS. Not yet done — needs the Mac.

---

### Phase 9 — RSS Feeds, Account, Settings, Stats, Polish

Two real endpoints not in prior phases were confirmed live against evan's server (2026-07-31) before
building against them: `GET /api/me/listening-stats` (the obvious `/api/me/stats` guess 404s) and
`GET /api/me/listening-sessions`. `/api/feeds` returned **403** — evan's account is `type: user` with
`permissions.update: false`, confirming RSS feed management is admin-gated server-side; see 9.1.

- [ ] 9.1 **RSS feed management**. **Deferred** — `GET /api/feeds` 403'd against evan's real (non-admin) account, confirming this is an admin-only server action. Genuinely can't build-and-verify the open/close request/response shape blind without admin access (no server source on this machine either, same reasoning as prior admin/mutating deferrals). The client *does* respect this permission boundary correctly: `SettingsScreen` only shows an "RSS Feeds" entry at all when `user.type` is `root`/`admin` (confirmed hidden for evan's real `user`-type account), so a non-admin user never sees a feature they can't use.
- [x] 9.2 Account screen: user info (username/email/type), server URL, download/upload permission flags, logout. Verified live with evan's real account data. **Extended 2026-08-01** with Update/Delete permission flags too — doubled as live confirmation that 7.3/7.4/delete-episode-from-server are genuinely permission-blocked (both false for evan's account), not just missing-server-source as previously written here. "Switch server/user" stays out of scope with the multi-server switcher itself (3.3).
- [x] 9.3 Settings, organized to match the reference app's taxonomy — **and every toggle is wired to real behavior, not a dead switch**: **Playback** (jump interval, now configurable — was fixed 30s per 5.5; scale-elapsed-time-by-speed, closes the 5.6 gap), **Sleep Timer** (default duration), **Data** (cellular streaming/download toggles, enforced via `connectivity_plus` in `PlaybackController`/`DownloadController` before each starts — blocked attempts surface a snackbar via a shared `cellularBlockNoticeProvider` that `MiniPlayer` listens for, since MiniPlayer is already mounted on nearly every screen), **User Interface** (haptic feedback — wired to the Now Playing play/pause button; keep-screen-awake — real `wakelock_plus` toggle tied to Now Playing's lifecycle; lock-to-portrait — real `SystemChrome.setPreferredOrientations` at app root; language — see 9.8), **Ereader** (the *same* global `EreaderSettingsPanel` from Phase 8, now shared between the in-reader sheet and Settings — confirmed live that a change made in one place applies in the other), **Advanced** (Logs, see 9.6). **Android Auto** section not added — nothing to configure yet (Milestone 4). **Appearance/skin** stays deliberately out — the slot is still reserved for Milestone 3's skin engine per the Phase 1.8/2 decision; a toggle here would have nothing real to switch between yet (single default theme).
- [x] 9.4 **Stats**: real 7-day bar chart, recent sessions, best day, daily average, days listened, streak, items finished, week listening — all computed from `GET /api/me/listening-stats`. Verified live against evan's real account: 573 days listened (all-time), a 6-day current streak, 63 items finished, a real per-day 7-day chart (Sat 0m → Tue 235m → Fri 165m), real recent-session entries. "Items finished" isn't in the stats payload (it has time-per-item, not a finished flag) — cross-referenced from `/api/me`'s `mediaProgress` list instead (same field already used for podcast episode state in Phase 7).
- [x] 9.5 **Year in Review**: no dedicated annual-recap endpoint exists (only `listening-stats`, confirmed) — built by aggregating that same data client-side, filtered to the current year, rather than guessing an unconfirmed endpoint. Total time this year, days active, top items by time listened.
- [x] 9.6 **Logs / debug** screen — a real, working log (drift-backed `LogEntries` table, survives restarts, capped at 500 entries), not a stub. Hooked into real failure paths: session token-refresh failure, progress-sync failure, download failure. View + clear, confirmed live (correctly showed "No log entries yet" — nothing failed during this session's testing, a genuine empty state).
- [x] 9.7 History screen: `GET /api/me/listening-sessions`, paginated infinite-scroll (same pattern as the library grid). Verified live against evan's real account — 1228 real sessions, confirmed pagination loads more on scroll.
- [x] 9.8 **Localization**: language picker wired into Settings → User Interface, but honestly scoped — only `app_en.arb` exists (confirmed by checking `lib/l10n/`), so the picker currently offers English only rather than fabricating 40 unverified translations. The `flutter_localizations`/ARB pipeline itself (0.12/1.5) is unchanged and ready to grow as real translations are added.
- [ ] 9.9 Real app icon + splash. **Deferred** — no real branding artwork exists to generate from, and `flutter_launcher_icons`/`flutter_native_splash` were already removed from `pubspec.yaml` in Phase 8 (a real, confirmed dependency conflict: every version compatible with `drift_dev`'s `cli_util` wants `image` ^4.x, which conflicts with `epub_view`/`epubx`'s `image` ^3.x — see Phase 8.1's pubspec note). Placeholder icons remain until real artwork exists and that conflict is revisited.
- [x] 9.10 Empty/error states: added the one real gap found — the full-library grid (4.4) showed a blank grid with no message for a genuinely empty library. Every other major screen already had a real empty/error state from its own phase (downloads, podcast episode list, recent episodes, history, connect-server/login network errors from 3.7) — confirmed by re-reading each screen rather than assuming.

> 🤖 **Android checkpoint: verified 2026-07-31** on the Pixel 8 Pro against evan's real Audiobookshelf server — driven live over adb. Settings screen renders the full real taxonomy with the RSS section correctly hidden (non-admin account); toggled "keep screen awake" and confirmed it persisted across navigation; Account screen showed real user/server data; Stats screen rendered a real 7-day chart and all tiles with real computed values; History screen showed real session data with working pagination; Logs screen showed the correct empty state; the sleep timer was started (moon icon filled) and cancelled (icon reverted) with playback continuing normally throughout. Two real bugs were caught and fixed *during this same Phase 7/8/9 session* via this on-device methodology (see Phase 8's entry) — this phase's testing didn't turn up a third, but every interactive control above was actually tapped, not just read from source.

---

## Milestone 3 — UI Customization & Skins

### Phase 2 — Design System & Theming Engine (the "flare")

Core functionality now exists from Milestones 1–2 — build the full skin engine against real screens instead
of placeholders, then retrofit it across them. (Note: the official app already has a "Use bookshelf view"
toggle, so a swappable shelf-vs-modern presentation is proven territory — we go further and make it a full
skin system.)

- [x] 2.1 Design tokens as a `ThemeExtension`/`AppTheme`: color roles (bg, surface, accent, text), spacing, radius, typography scales — never hardcoded per-widget. **Built 2026-08-01**: `AppSpacing`/`AppRadii` (from Phase 1.8) plus a new `AppSkinStyle` extension carrying skin-specific rendering hooks (frosted-surface flag/blur sigma, cover style) — every concrete `Skin` sets its own values rather than screens hardcoding them. Color roles ride Material 3's `ColorScheme` (already the existing convention throughout the app) rather than a bespoke color-role extension.
- [x] 2.2 **Glass/modern skin**: frosted surfaces (`BackdropFilter` + `ImageFilter.blur`), translucent cards, gradients, dark-first palette. **Built 2026-08-01**: cool-blue dark-first palette, translucent cards, and a real `GlassSurface` widget (genuine `BackdropFilter` blur, not just a translucent color) applied behind the home shell's app bar via `Scaffold.extendBodyBehindAppBar` — verified live, content visibly blurs as it scrolls underneath. No gradient backgrounds yet — flat surface color only; a real nice-to-have follow-up.
- [x] 2.3 **Bookshelf skin**: warm wood/paper textures, skeuomorphic shelf grid, book-spine cover styling. **Built 2026-08-01, simplified**: warm wood-brown palette, opaque cards, sharper/smaller radii, and real book-spine cover shading (edge highlight + page-block shadow + drop shadow, see 2.7) — procedural, not a literal wood/paper texture image, since no branding artwork exists yet (Phase 9.9). A `CustomPainter` wood-grain texture is a good later polish pass, not done here.
- [x] 2.4 **Skin switcher** abstraction: a `Skin` interface both themes implement, runtime-selectable, persisted to storage. **Built 2026-08-01**: `Skin`/`SkinId`/`skinByName` in `lib/core/theme/`, persisted via a new `AppSettings.skinId` field through the existing settings JSON-blob pattern, flowing into `MaterialApp.theme`.
- [ ] 2.5 Core shared components on the token system: buttons, cards, list tiles, progress bars, bottom sheets, tab bar, mini-player slot — both skins reuse the tree with different token values. **Partially covered, not a real shared-component library**: `CardThemeData`/`AppBarTheme`/`DividerThemeData` are set per-skin so stock Material widgets (`Card`, `AppBar`, `Divider`) already reuse the tree via Flutter's own theming — but there's no dedicated `lib/widgets/` set of skin-aware buttons/bottom-sheets/tab-bar built, and most screens haven't been audited for stray hardcoded colors bypassing the theme. Real remaining scope, not done in this pass.
- [x] 2.6 **Settings → Appearance** screen to preview/switch skins live (fills the slot left in Phase 9.3). **Built 2026-08-01**: switching *is* the live preview — tapping a skin card applies it immediately and the whole app re-themes, verified live on-device. Each card also previews the *other* skin's colors before switching (reads that skin's own `buildTheme()`, not the active one). **Light/dark/black as a dimension within each skin is not built** — each skin ships one fixed dark-first palette only; a real simplification given the scope of 2 skins × 3 brightness variants, flagged for later.
- [x] 2.7 Retrofit the full library view (Phase 4.4) with real skin divergence — shelf-of-spines vs. modern cover grid. **Built 2026-08-01**: `_BookSpineFrame` gives Bookshelf covers real spine shading (procedural, see 2.3); Glass Modern keeps the plain modern grid. Verified live in both skins on the Pixel 8 Pro. Other major screens (item detail, downloads, now playing) still use their pre-skin-engine layout — real tokens/colors apply automatically via `Theme.of(context)`, but no skin-specific structural divergence was added to them in this pass, only the library grid PLAN.md explicitly calls out here.
- [x] 2.8 **Accessibility pass**: font scaling, screen-reader labels, and **contrast on the glass skin**. **Light pass done 2026-08-01, not a full audit**: added a semantic label to the skin-switcher cards, spot-checked 1.3x system font scale on Settings/Appearance (wraps cleanly, no clipping). No formal contrast-ratio verification was run against the glass skin's translucent cards, and no broader screen-reader-label sweep across the app — both worth a dedicated follow-up pass.

> 🤖 **Android checkpoint: verified 2026-08-01** on the Pixel 8 Pro — confirmed Glass Modern renders as the new default (distinct cool-dark palette vs. the old single coffee-brown theme), live-switched to Bookshelf from Settings → Appearance (whole app re-themed instantly, selection persisted across an app restart), confirmed the library grid's real per-skin divergence (book-spine shading vs. plain modern cards) against evan's real 60-item library, and confirmed the frosted app-bar blur genuinely blurs scrolling content underneath it (not just a static translucent color) on Glass Modern. No jank observed scrolling either skin on real hardware. 2.5 (shared component library) and a full 2.8 accessibility audit remain open — see their notes above.

---

## Milestone 4 — Car Integration: Android Auto & CarPlay

### Phase 10 — Car Integrations: CarPlay & Android Auto (final feature milestone)

The last committed feature set before release. Both platforms project a **browsable content tree** + a
**Now-Playing** screen onto the car head unit; playback commands route through the same `audio_service` handler
from Phase 5. Build the content tree once, then adapt it to each platform's API. Design for **driving reality**:
big tap targets, shallow menus, and downloaded/offline content must be browsable with no signal. Since
Milestone 2 already shipped podcasts and e-books, the content tree can include them from the start here.

**Shared foundation**
- [ ] 10.1 Car content-tree provider — one source of truth mapping app data → browsable nodes: root → Continue Listening, Libraries, Series, Authors, Collections, Playlists, Downloaded/Local → items → play. Reuses the media-session foundation from 5.12.
- [ ] 10.2 Ensure **downloaded + on-device local-media items** appear in the tree and play with zero connectivity (you're often driving offline).
- [ ] 10.3 Map transport actions (play/pause, jump fwd/back, next/prev chapter, playback speed, mark finished) to car-safe controls; keep now-playing metadata (cover, title, author, chapter, progress) live.

**Android Auto**
- [ ] 10.4 Browse tree via `audio_service`'s `MediaBrowserService` (`getChildren`/`onLoadChildren`) — libraries → series/authors/collections → items.
- [ ] 10.5 Android-Auto settings: alphabetical drawdown limit (grouping), series-books order (asc/desc) — matching the reference app.
- [ ] 10.6 `AndroidManifest` wiring (`automotive_app_desc.xml`, `MediaBrowserService` intent filter) + a pass against Google's Android-for-Cars content/quality guidelines.
- [ ] 10.7 Google Assistant "play &lt;book&gt;" voice handling (nice-to-have).

**CarPlay** (this goes *beyond* the reference app, which only has standard Now-Playing)
- [ ] 10.8 Confirm the **CarPlay audio-app entitlement** (`com.apple.developer.carplay-audio`) requested in 0.13 is granted and added to the provisioning profile.
- [ ] 10.9 Implement CarPlay via `flutter_carplay` (or native Swift `CPTemplateApplicationSceneDelegate`): a `CPListTemplate` browse hierarchy mirroring the shared content tree + `CPNowPlayingTemplate` with transport buttons.
- [ ] 10.10 Add the CarPlay scene delegate + entitlement to the iOS project; wire it to the same `audio_service` handler.
- [ ] 10.11 Siri / voice search hooks for "play &lt;book&gt;" (nice-to-have).
- [ ] 10.12 Verify graceful no-signal behavior (browse downloaded/local content only).

> 🤖 **Android checkpoint:** test Android Auto with the **Desktop Head Unit (DHU)** (or a real car) — browse the full tree, play a downloaded book in airplane mode, confirm transport controls + live now-playing metadata.
>
> 🍎 **Xcode checkpoint 5 (major landmark):** test CarPlay in the **Xcode CarPlay Simulator** (Simulator → I/O → External Displays → CarPlay) — browse hierarchy, Now-Playing controls, offline playback. Requires the CarPlay entitlement provisioned; confirm the signing profile includes it.

---

## Milestone 5 — Stretch Goals & Release Prep

### Phase 11 — Stretch Goals (optional; only once core is solid)

- [ ] 11.1 **Chromecast** — Android-only in the reference app (CastManager/CastPlayer). Scope to Android; iOS has no cast support in the reference app, so not a parity gap.
- [ ] 11.2 Home-screen / lock-screen glanceable playback widget.
- [ ] 11.3 Tablet/foldable responsive layouts.
- [ ] 11.4 Additional community-style skins beyond the initial two.
- [ ] 11.5 Custom-time playback start ("start playback at HH:MM") and other power-user conveniences seen in the app.

---

### Phase 12 — Release Prep

- [ ] 12.1 GitHub Actions **macOS-runner** workflow to build the iOS side automatically on push — the CI path so you don't need daily Mac access.
- [ ] 12.2 App Store Connect + Google Play Console listings; screenshots per skin.
- [ ] 12.3 Versioning/changelog convention.
- [ ] 12.4 Beta distribution: TestFlight (iOS) + Play internal testing track (Android).
- [ ] 12.5 Localization QA pass across shipped languages.

> 🍎 **Xcode checkpoint 6 (final landmark):** full release-configuration archive — signing, entitlements, App Store build — before TestFlight submission.

---

## Feature Parity Checklist

Every **client-facing** feature found in the server README, app README, and app source, mapped to a phase.
Check these off as parity is reached — this is the "nothing dropped" ledger.

**Connection & Account**
- [ ] Connect by server URL · Phase 3.1
- [ ] Username/password login (+ v2.26.0 auth) · 3.2
- [ ] Multiple servers / switch server & user · 3.3
- [ ] Secure token storage + refresh + re-login · 3.4
- [ ] Respect server-side user permissions (download access, library access) · 3.5
- [ ] Websocket live sync + connection status (metered/unmetered wifi/cellular) · 3.6
- [ ] Mask server address · 3.8
- [ ] Account screen / logout · 9.2

**Library & Discovery**
- [x] Libraries + switcher, books vs podcasts · 4.2
- [x] Home shelves (continue listening/reading/series/books/episodes, recently added, newest, discover, listen/read again) · 4.3
- [ ] Bookshelf view vs modern grid · 4.4 / Phase 2.7
- [ ] Authors / Series (collapse series) / Collections / Playlists · 4.5
- [ ] Filter & sort · 4.6
- [ ] Search (incl. podcast RSS-URL search) · 4.7
- [x] Item detail (metadata, chapters, tracks, tags, genres, narrators) · 4.8
- [ ] Playlist create / add-to / remove / reorder · 4.5 + 4.8
- [x] Mark finished / not finished · 5.10 — discard/reset progress as a separate action not built

**Playback**
- [ ] Stream (direct + transcode), all formats · 5.1 — direct play only, no transcode fallback
- [x] Mini-player + Now Playing · 5.2
- [x] Background playback · 5.3
- [x] Lock-screen/notification controls · 5.4 — seek-on-controls toggle not built
- [x] Chapters + jump fwd/back intervals · 5.5 — fixed 30s, not yet customizable
- [x] Playback speed · 5.6 — scale-elapsed-by-speed display option not built
- [x] Sleep timer (manual duration) · 5.7 / 9.3 — end-of-chapter/shake-to-reset/fade-out/chime not built
- [ ] Bookmarks · 5.8
- [x] Progress sync · 5.9 — no dedicated sync-failed UI, but failures are logged (9.6) and durably queued for retry (6.7)
- [ ] Volume-key navigation · 5.11
- [x] Media-session foundation (now-playing metadata + queue) · 5.12
- [ ] Keep-screen-awake, lock player, MP3 index seeking · 5.13
- [ ] **Android Auto** (full browse tree + settings) · 10.4–10.6
- [ ] **CarPlay** (full browse hierarchy + Now-Playing; beyond reference app) · 10.8–10.10
- [ ] **Chromecast (Android-only)** · 11.1

**Downloads & Local Media**
- [x] Download server item · 6.1 — books only, no server download-permission pre-check
- [x] Series download · 6.2 — built without full series-browse UI, reuses the items-filter endpoint
- [x] Download location selection · 6.3 — internal storage only, no shared-storage option
- [x] Local item ↔ server/user linking · 6.4 — single-session app, multi-account edge case not handled
- [x] Downloads screen + queue · 6.5 — no clear-queue action
- [x] Offline playback · 6.6 — verified with real connectivity cut; cold-start-while-offline gap found and fixed
- [x] Offline→online progress sync · 6.7 — real durable queue, survives app restarts, verified live
- [x] **On-device local-media import** · 6.8 — single-file import (not a folder scan, see 6.8 for why), verified live
- [x] Cellular download/stream controls · 6.9 — built, not verified against a real cellular-only connection
- [x] Storage management · 6.10 — total/per-item size, low-storage warning, bulk-delete, verified live

**Podcasts**
- [x] Podcast library + episode list/state · 7.1–7.2 — built and verified on-device
- [ ] Add podcast (term/RSS) · 7.3 — deferred (server-mutating create, needs server source)
- [ ] Auto-download episodes · 7.4 — deferred with 7.3
- [x] Episode download/offline + delete (local/server) · 7.5 — device download/offline/local-delete verified on real hardware; delete-from-server deferred
- [x] Latest-episodes feed · 7.6 — built and verified; `/recent-episodes` shape confirmed against real server response

**E-books & Comics**
- [x] EPUB reader + TOC + position sync · 8.1 — built and verified on-device against a real illustrated book
- [x] Ereader settings (font/scale/boldness/spacing/theme) · 8.2 — layout (Auto/Single page) not applicable, epub_view is continuous-scroll only
- [x] PDF reader · 8.3 — built, analyze-clean; not verified on-device (no PDF item found in evan's library)
- [x] CBZ comics · 8.4 — built and verified on-device against a real 128MB archive; CBR unsupported (no pure-Dart RAR decoder)
- [ ] Primary/supplementary ebook · 8.5 — deferred, never observed a multi-ebookFile item to build against
- [ ] Send ebook to device (Kindle) · 8.6 — deferred, server-mutating SMTP-gated action

**RSS, Stats, System**
- [ ] Open/close & manage RSS feeds · 9.1 — deferred, admin-gated and evan's account is non-admin (confirmed via a real 403)
- [x] Settings taxonomy (playback/data/UI/ereader/sleep/advanced) · 9.3 — built and verified, every toggle real; android-auto has nothing to configure until Milestone 4
- [x] Stats (chart, sessions, streaks, finished) · 9.4 — built and verified against real account data
- [x] Year in Review · 9.5 — built (client-side aggregation, no dedicated endpoint exists)
- [x] Logs/debug · 9.6 — built and verified, hooked into real failure paths
- [x] History · 9.7 — built and verified against 1228 real sessions
- [x] Localization (English only so far) · 0.12 / 1.5 / 9.8 — picker built; only `app_en.arb` exists, honestly scoped rather than claiming 40 languages
- [x] Haptic feedback · 9.3 — wired to Now Playing's play/pause

---

## Explicitly Out of Scope (server-side features, not the client's job)

These appear in the **server** README but are server/web-admin functions — Steeped consumes their
*results* (e.g. displays fetched metadata, plays transcoded/merged files) but does not implement them:

- Uploading books/podcasts, bulk drag-and-drop upload
- Metadata + automated daily backups
- Server-side library auto-scan / update detection (we react to it via websocket, but don't run scans)
- Merge audio files into a single m4b
- Embed metadata/cover into audio files
- Chapter *editor* and Audnexus chapter *lookup* (we display chapters; editing is server/web)
- Fetch metadata/cover art from external sources
- Multi-user *administration* / permission *assignment* (we *respect* permissions; we don't manage them)
- Progressive Web App (that's the web client)

---

## Working Notes

- **Three hard, platform-divergent milestones:** Phase 5 / Milestone 1 (background audio), Phase 6 / Milestone 2 (offline downloads + local media + sandboxing), and Phase 10 / Milestone 4 (CarPlay + Android Auto). Everything else is near write-once-run-anywhere in Flutter. Budget the bulk of your Mac/Xcode time around these three.
- **CarPlay has a long-lead dependency:** the Apple CarPlay audio entitlement (0.13) needs Apple's approval, so request it at the very start (Milestone 1) even though CarPlay itself is built last (Milestone 4).
- **Skins are deliberately late (Milestone 3):** core screens get a single default look first (Phase 1.8), so the skin engine (Phase 2) is built against real content instead of placeholders — avoids reworking an elaborate theming abstraction before it's been proven against actual screens.
- **Test on Android continuously** (fast, no Mac trip); reserve **Xcode** for the milestone checkpoints in the cadence table, plus the early smoke test so iOS build breakage never surprises you late.
- Keep this file's checkboxes updated as you build — it doubles as a changelog and the parity ledger.
- If a feature turns out to depend on a server API you're unsure of, confirm the response shape against `~/Code/audiobookshelf` (server source) or https://api.audiobookshelf.org before implementing the client side.
