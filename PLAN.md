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

- [ ] 5.1 `just_audio` + `audio_service` streaming from the server. Support **Direct play vs server Transcode** (the app requests a transcoded stream when needed) and handle all common audio formats.
- [ ] 5.2 Mini-player (persistent bottom bar) + full-screen "Now Playing".
- [ ] 5.3 Background playback (alive when backgrounded/locked).
- [ ] 5.4 Lock-screen / notification media controls; "allow position seeking on media controls" option.
- [ ] 5.5 Chapters + chapter track, chapter navigation, customizable **jump forward/back** intervals.
- [ ] 5.6 Playback speed + "scale elapsed time by speed" option.
- [ ] 5.7 **Sleep timer (full feature set):** manual duration, **end-of-chapter**, **auto sleep timer** (auto-start within a time window) with auto-rewind, **shake-to-reset** (+ shake-sensitivity), vibrate-on-reset toggle, audio **fade-out** toggle, "almost done" chime at 30s.
- [ ] 5.8 Bookmarks (create/list/remove, "Your Bookmarks").
- [ ] 5.9 Progress sync to server (session reporting every ~15s–1m) + **"progress sync failed"** handling/retry.
- [ ] 5.10 Mark as **Finished / Not Finished**; discard/reset progress.
- [ ] 5.11 **Navigate with volume keys** (on/off, mirrored, allow-while-playing).
- [ ] 5.12 **Media-session foundation**: expose proper now-playing metadata + a playback queue through `audio_service` — the substrate the **CarPlay & Android Auto** browse trees build on in **Phase 10 (Milestone 4)**. At this stage iOS already shows standard Control-Center/lock-screen now-playing, which also surfaces in CarPlay's Now-Playing screen automatically.
- [ ] 5.13 Lock/unlock player UI; keep-screen-awake toggle; MP3 index-seeking advanced option.

> 🤖 **Android checkpoint:** background playback + lock-screen controls survive screen-off, app-switch, phone-lock; volume-key nav; sleep-timer behaviors. (Full Android Auto browse UI is tested in Milestone 4.)
>
> 🍎 **Xcode checkpoint 2 (major landmark):** iOS **Background Modes → Audio** entitlement, `audio_service` iOS config, silent-switch behavior, Control-Center/lock-screen controls (these auto-surface in CarPlay's Now-Playing; the full CarPlay browse experience comes in Milestone 4). First point where iOS entitlements truly matter.

---

## Milestone 2 — Content, Offline & Downloads

### Phase 6 — Offline Downloads & On-Device Local Media (major milestone)

Two distinct capabilities the reference app has: (a) **downloading server items** for offline use, and
(b) **importing/scanning on-device folders** of media that never came from the server ("Local Media").

- [ ] 6.1 "Download" action on a book/episode → background download to local storage (respect the user's server download permission).
- [ ] 6.2 **Series download** — download all missing books in a series at once, with a size/count confirmation.
- [ ] 6.3 **Download location selection**: Internal App Storage vs shared-storage folder (Android SD/shared). Note Android-10-and-below internal-only behavior.
- [ ] 6.4 Local library model distinguishing server item vs **downloaded local item** vs **imported local-media item**; link downloaded media to its **server + user** for progress sync (handle "linked to different server/user" cases).
- [ ] 6.5 Downloads screen: in-progress + **download queue** (with clear-queue), completed list, delete/manage.
- [ ] 6.6 Offline playback with zero connectivity.
- [ ] 6.7 Sync local progress back to server on reconnect (queue + retry).
- [ ] 6.8 **Local Media folders**: let the user pick device folders, **scan** them for audiobooks/podcasts, and play them without any server (mirrors `FolderScanner`/"Manage Local Files"/"New Folder"). Show "No Media Folders" empty state.
- [ ] 6.9 **Cellular-data controls**: separate "download using cellular" and "stream using cellular" toggles; confirm-on-metered prompts; block when disallowed.
- [ ] 6.10 Storage management: space used, bulk-delete, low-storage warnings.

> 🤖 **Android checkpoint:** download a full book, kill app mid-download to confirm resume, go airplane-mode and play offline; add a local-media folder and scan/play a sideloaded file; toggle cellular controls on a metered connection.
>
> 🍎 **Xcode checkpoint 3 (major landmark):** iOS **background URLSession** download behavior + **app-sandbox file paths** differ substantially. Verify downloads survive backgrounding, offline playback works, and local-file access behaves on a real iPhone/Simulator.

---

### Phase 7 — Podcasts

- [ ] 7.1 Podcast library view (separate media type).
- [ ] 7.2 Episode list per podcast; played/unplayed/incomplete state; "# of episodes / N incomplete".
- [ ] 7.3 **Add podcast** flow (subscribe via server; search term or RSS URL) — "Podcast created" success/fail toasts.
- [ ] 7.4 **Auto-download episodes** setting per podcast.
- [ ] 7.5 Episode download + offline (reuses Phase 6 engine); delete local episode and delete-episode-from-server (with the destructive-action warning).
- [ ] 7.6 Latest/newest-episodes feed; new-episode indicators; next-episode action.

> 🤖 **Android checkpoint:** subscribe (by term and by RSS URL), enable auto-download, download an episode, confirm it flows through the shared playback/download engine with no special-cased bugs.

---

### Phase 8 — E-Books & Comics

- [ ] 8.1 **EPUB reader** (`epub_view`): pagination, table of contents, reading-position sync to server.
- [ ] 8.2 **Ereader settings**: font family (Sans/Serif), font scale, font boldness, line spacing, layout (Auto / Single page), theme (Light/Dark/Black).
- [ ] 8.3 **PDF reader**.
- [ ] 8.4 **Comic archive (CBZ/CBR)** reader via `archive` extraction + page viewer.
- [ ] 8.5 Primary vs supplementary ebook handling ("set as primary/supplementary", "has ebook / has supplementary ebook").
- [ ] 8.6 **Send Ebook to Device** (e.g. Kindle) action — parity with server/app "send to device".
- [ ] 8.7 Unify "continue reading" alongside "continue listening" on the home shell.

> 🤖 **Android checkpoint:** read an EPUB and a CBZ end-to-end; reading position persists and syncs; ereader settings apply live.
>
> 🍎 **Xcode checkpoint 4:** confirm EPUB/PDF/CBZ rendering + on-device file access parity on iOS.

---

### Phase 9 — RSS Feeds, Account, Settings, Stats, Polish

- [ ] 9.1 **RSS feed management**: open/close an RSS feed for a podcast or audiobook; feed slug, custom owner name/email, prevent-indexing toggle; show "RSS Feed is Open" state and feed URL preview. Include the HTTPS/PubDate warnings the app shows.
- [ ] 9.2 Account screen (user info, logout, switch server/user).
- [ ] 9.3 Settings, organized to match the reference app's taxonomy: **Playback**, **Data** (cellular), **User Interface** (haptic feedback, keep-screen-awake, lock-orientation, language, theme, bookshelf view), **Android Auto**, **Ereader**, **Sleep Timer**, **Advanced**. An **Appearance/skin** section is added here later, once Milestone 3 (Phase 2) builds the skin system — leave a slot for it now.
- [ ] 9.4 **Stats**: minutes-listening 7-day chart, recent sessions, best day, daily average, days listened, streak ("in a row"), items finished, week listening.
- [ ] 9.5 **Year in Review** annual recap (show/hide).
- [ ] 9.6 **Logs / debug** screen (view/clear logs) for troubleshooting self-hosted connectivity — genuinely useful, mirrors `logs.vue`.
- [ ] 9.7 History screen.
- [ ] 9.8 **Localization**: wire up real translations (start with English; the pipeline exists from Phase 0.12/1.5). Language picker in UI settings.
- [ ] 9.9 Real app icon + splash (replace placeholders); consider an icon that reflects the coffee/book brand.
- [ ] 9.10 Empty/error states across every screen (no server, empty bookshelf, no items/collections/series/bookmarks, failed download, no network).

> 🤖 **Android checkpoint:** full walkthrough — every screen, real server, real device; open/close an RSS feed; language switch; stats + Year-in-Review.

---

## Milestone 3 — UI Customization & Skins

### Phase 2 — Design System & Theming Engine (the "flare")

Core functionality now exists from Milestones 1–2 — build the full skin engine against real screens instead
of placeholders, then retrofit it across them. (Note: the official app already has a "Use bookshelf view"
toggle, so a swappable shelf-vs-modern presentation is proven territory — we go further and make it a full
skin system.)

- [ ] 2.1 Design tokens as a `ThemeExtension`/`AppTheme`: color roles (bg, surface, accent, text), spacing, radius, typography scales — never hardcoded per-widget. (Extends the minimal baseline from Phase 1.8.)
- [ ] 2.2 **Glass/modern skin**: frosted surfaces (`BackdropFilter` + `ImageFilter.blur`), translucent cards, gradients, dark-first palette.
- [ ] 2.3 **Bookshelf skin**: warm wood/paper textures, skeuomorphic shelf grid, book-spine cover styling.
- [ ] 2.4 **Skin switcher** abstraction: a `Skin` interface both themes implement, runtime-selectable, persisted to storage (a genuinely swappable design system, beyond light/dark `ThemeMode`).
- [ ] 2.5 Core shared components on the token system: buttons, cards, list tiles, progress bars, bottom sheets, tab bar, mini-player slot — both skins reuse the tree with different token values.
- [ ] 2.6 **Settings → Appearance** screen to preview/switch skins live (fills the slot left in Phase 9.3). Also expose light/dark/black theme (the app has Light/Dark/Black) as a dimension within each skin.
- [ ] 2.7 Retrofit the full library view (Phase 4.4) with real skin divergence — shelf-of-spines vs. modern cover grid.
- [ ] 2.8 **Accessibility pass**: font scaling, screen-reader labels, and **contrast on the glass skin** (translucent surfaces over blur are a real contrast risk — verify text legibility).

> 🤖 **Android checkpoint:** run both skins on-device; check for jank on blur/glass (frosted blur is the top perf trap — verify framerate on real hardware, not emulator).

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
- [ ] Mark finished / not finished, discard progress · 5.10

**Playback**
- [ ] Stream (direct + transcode), all formats · 5.1
- [ ] Mini-player + Now Playing · 5.2
- [ ] Background playback · 5.3
- [ ] Lock-screen/notification controls + seek-on-controls · 5.4
- [ ] Chapters + jump fwd/back intervals · 5.5
- [ ] Playback speed + scale-elapsed-by-speed · 5.6
- [ ] Sleep timer (manual, end-of-chapter, auto-timer, shake-to-reset, vibrate, fade-out, chime) · 5.7
- [ ] Bookmarks · 5.8
- [ ] Progress sync + sync-failed handling · 5.9
- [ ] Volume-key navigation · 5.11
- [ ] Media-session foundation (now-playing metadata + queue) · 5.12
- [ ] Keep-screen-awake, lock player, MP3 index seeking · 5.13
- [ ] **Android Auto** (full browse tree + settings) · 10.4–10.6
- [ ] **CarPlay** (full browse hierarchy + Now-Playing; beyond reference app) · 10.8–10.10
- [ ] **Chromecast (Android-only)** · 11.1

**Downloads & Local Media**
- [ ] Download server item · 6.1
- [ ] Series download · 6.2
- [ ] Download location selection · 6.3
- [ ] Local item ↔ server/user linking · 6.4
- [ ] Downloads screen + queue · 6.5
- [ ] Offline playback · 6.6
- [ ] Offline→online progress sync · 6.7
- [ ] **On-device local-media folders (scan/import)** · 6.8
- [ ] Cellular download/stream controls · 6.9
- [ ] Storage management · 6.10

**Podcasts**
- [ ] Podcast library + episode list/state · 7.1–7.2
- [ ] Add podcast (term/RSS) · 7.3
- [ ] Auto-download episodes · 7.4
- [ ] Episode download/offline + delete (local/server) · 7.5

**E-books & Comics**
- [ ] EPUB reader + TOC + position sync · 8.1
- [ ] Ereader settings (font/scale/boldness/spacing/layout/theme) · 8.2
- [ ] PDF reader · 8.3
- [ ] CBZ/CBR comics · 8.4
- [ ] Primary/supplementary ebook · 8.5
- [ ] Send ebook to device (Kindle) · 8.6

**RSS, Stats, System**
- [ ] Open/close & manage RSS feeds · 9.1
- [ ] Settings taxonomy (playback/data/UI/android-auto/ereader/sleep/advanced) · 9.3
- [ ] Stats (chart, sessions, streaks, finished) · 9.4
- [ ] Year in Review · 9.5
- [ ] Logs/debug · 9.6
- [ ] History · 9.7
- [ ] Localization (40 languages) · 0.12 / 1.5 / 9.8
- [ ] Haptic feedback · 9.3

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
