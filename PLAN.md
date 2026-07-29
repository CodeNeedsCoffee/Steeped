# BooksNeedCoffee — Build Plan

A Flutter (single codebase, Android + iOS) client for a self-hosted **Audiobookshelf** server, aiming for
**full feature parity** with the official [audiobookshelf-app](https://github.com/advplyr/audiobookshelf-app)
(server connection, streaming, downloads, on-device local media, podcasts, e-books, Android Auto, casting, etc.)
but with a custom design system: a **glass/modern** look and a **user-selectable "skin"**
(e.g. a literal wooden-bookshelf skin vs. a frosted-glass modern skin).

Reference material already on this machine:
- `~/Code/audiobookshelf-app` — official client source (Nuxt/Capacitor). Feature/behavior reference, not code to port — we rebuild natively in Dart. The full feature surface below was derived from its `strings/en-us.json`, `pages/`, `store/`, and native Kotlin/Swift plugins.
- `~/Code/audiobookshelf` — the server source, for confirming API response shapes.
- Official API docs: https://api.audiobookshelf.org

> This plan was cross-checked against the **server `readme.md`**, the **app `readme.md`**, and the app's actual
> source (strings, pages, native plugins). Every client-facing feature found is mapped to a phase in the
> **[Feature Parity Checklist](#feature-parity-checklist)** at the bottom — use that section to confirm nothing was dropped.

---

## Testing Cadence (read this first)

Two separate rhythms, because you develop on Linux and have a Mac nearby (not primary):

- 🤖 **Android — semi-frequent, on your plugged-in device.** Test at the **end of every phase**, and any time a
  sub-item touches native behavior (playback, downloads, notifications). This is your fast inner loop — no Mac
  trip required. Every phase below ends with an 🤖 checkpoint.
- 🍎 **iOS / Xcode — large milestones only, on the Mac.** Reserve Mac sessions for the points where iOS genuinely
  diverges from Android (background audio entitlements, download/session sandboxing, file storage, release
  signing). These are called out inline as 🍎 checkpoints and summarized here:

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

## Phase 0 — Tech Stack Decisions

- [ ] 0.1 State management: **Riverpod** (recommended for async server/streaming state) vs Bloc.
- [ ] 0.2 Navigation: **go_router** — declarative routing + deep links (open-a-book links later).
- [ ] 0.3 Networking: **dio** — interceptors for auth headers/token refresh.
- [ ] 0.4 Real-time: **web_socket_channel** (or socket.io client) — Audiobookshelf uses a **websocket** for live updates; the server explicitly requires websocket support. Needed for progress/library sync and metered-connection awareness.
- [ ] 0.5 Local database: **drift** (SQLite) or **Isar** — library metadata, download records, local-media index, playback-progress cache.
- [ ] 0.6 Secure storage: **flutter_secure_storage** — server URL + auth token (Keychain on iOS, Keystore on Android).
- [ ] 0.7 Audio: **just_audio** + **audio_service** — background playback, lock-screen/notification controls, Android Auto & CarPlay Now-Playing.
- [ ] 0.8 Downloads: **background_downloader** — resumable background downloads with queue.
- [ ] 0.9 E-books: `epub_view`/`epubx` (EPUB), `pdfx`/`syncfusion_flutter_pdfviewer` (PDF), `archive` (CBZ/CBR).
- [ ] 0.10 Casting: **Android-only** in the reference app — pick a Cast plugin (e.g. `flutter_chrome_cast`) but scope it to Android (Phase 11).
- [ ] 0.11 Connectivity: **connectivity_plus** — detect metered wifi/cellular for the cellular-data controls.
- [ ] 0.12 Localization: **flutter_localizations** + `intl` / ARB files — the reference app ships **40 languages**; architect for i18n from day one even if you launch with English.
- [ ] 0.13 Car integrations: **`audio_service`** already backs **Android Auto** (media-browser). For **CarPlay** pick **`flutter_carplay`** (or native Swift CarPlay templates). **Request the CarPlay audio-app entitlement (`com.apple.developer.carplay-audio`) from Apple now** — approval gates the feature and can take time, even though it's implemented late (Phase 10).
- [ ] 0.14 Write these decisions into `README.md` once confirmed.

> 🤖 No checkpoint — decisions only, no code.

---

## Phase 1 — Project Skeleton & Architecture

- [ ] 1.1 Folder structure: `lib/core` (theme, networking, storage, i18n), `lib/features/<feature>` (auth, library, player, downloads, localmedia, ebook, podcasts, settings, stats), `lib/models`, `lib/widgets`.
- [ ] 1.2 Add chosen packages to `pubspec.yaml`; `flutter pub get`.
- [ ] 1.3 Riverpod `ProviderScope` at app root.
- [ ] 1.4 `go_router` with placeholder routes: splash, connect-to-server, login, home shell, settings.
- [ ] 1.5 i18n scaffolding (ARB files, `intl` codegen) with an English baseline — so strings are externalized from the start.
- [ ] 1.6 Lint rules (`flutter_lints`) + `analysis_options.yaml`.
- [ ] 1.7 Placeholder app icon + splash (`flutter_launcher_icons`, `flutter_native_splash`) — real branding in Phase 9.

> 🤖 **Android checkpoint:** run skeleton on device — launches, navigates placeholder screens, hot reload works on real hardware.
>
> 🍎 **Xcode smoke checkpoint:** open on the Mac and confirm the iOS shell **builds and launches on the Simulator** at all. Do this now, before features stack up, so any iOS toolchain/signing issue surfaces early and cheap.

---

## Phase 2 — Design System & Theming Engine (the "flare")

Build this as an engine early — every later screen consumes it. (Note: the official app already has a
"Use bookshelf view" toggle, so a swappable shelf-vs-modern presentation is proven territory — we go further and make it a full skin system.)

- [ ] 2.1 Design tokens as a `ThemeExtension`/`AppTheme`: color roles (bg, surface, accent, text), spacing, radius, typography scales — never hardcoded per-widget.
- [ ] 2.2 **Glass/modern skin**: frosted surfaces (`BackdropFilter` + `ImageFilter.blur`), translucent cards, gradients, dark-first palette.
- [ ] 2.3 **Bookshelf skin**: warm wood/paper textures, skeuomorphic shelf grid, book-spine cover styling.
- [ ] 2.4 **Skin switcher** abstraction: a `Skin` interface both themes implement, runtime-selectable, persisted to storage (a genuinely swappable design system, beyond light/dark `ThemeMode`).
- [ ] 2.5 Core shared components on the token system: buttons, cards, list tiles, progress bars, bottom sheets, tab bar, mini-player slot — both skins reuse the tree with different token values.
- [ ] 2.6 **Settings → Appearance** screen to preview/switch skins live. Also expose light/dark/black theme (the app has Light/Dark/Black) as a dimension within each skin.

> 🤖 **Android checkpoint:** run both skins on-device; check for jank on blur/glass (frosted blur is the top perf trap — verify framerate on real hardware, not emulator).

---

## Phase 3 — Server Connection & Authentication

- [ ] 3.1 "Connect to Server" screen: enter URL, validate reachability against a known Audiobookshelf endpoint.
- [ ] 3.2 Login (username/password) → auth-token exchange. Handle the v2.26.0+ auth flow (older servers show a re-login/upgrade warning in the reference app).
- [ ] 3.3 **Multiple saved servers/accounts** with a "Switch Server/User" switcher.
- [ ] 3.4 Store token + URL in secure storage; `dio` interceptor attaches auth header, handles 401 → token refresh → re-login.
- [ ] 3.5 Persisted "current user/session" provider (`me`), including the user's **server-side permissions** (some users can't download, or lack access to certain libraries — the client must respect these).
- [ ] 3.6 **Websocket connection** to the server for live updates; surface connection status ("connected over metered/unmetered wifi/cellular", "not connected").
- [ ] 3.7 Offline/unreachable-server states handled gracefully (foundation for offline downloads).
- [ ] 3.8 "Mask server address" privacy toggle (minor parity item).

> 🤖 **Android checkpoint:** connect to your real server over the home network; login + token persistence survives app restart; websocket status shows correctly.
>
> 🍎 **Xcode checkpoint 1:** verify server connect + **secure token storage on iOS (Keychain)** and websocket connectivity on a real network — Keychain semantics differ from Android Keystore.

---

## Phase 4 — Library Browsing

- [ ] 4.1 Data models: Library, LibraryItem (book/podcast), Author, Series, Collection, Playlist — matching API shapes (title, author, narrators, series, genres, tags, publish year, tracks, chapters, mediaType).
- [ ] 4.2 Fetch/list libraries; library switcher; media-type awareness (books vs podcasts).
- [ ] 4.3 Home shell rows: **Continue Listening / Continue Reading / Continue Series / Continue Books / Continue Episodes**, Recently Added, Recent Series, Newest Authors, Newest Episodes, Listen Again / Read Again, Discover.
- [ ] 4.4 Full library view — where the two skins diverge most (shelf-of-spines vs. modern cover grid). Honor the bookshelf-view concept as part of the skin.
- [ ] 4.5 Authors, Series (with **collapse series**), Collections, Playlists browse screens.
- [ ] 4.6 **Filtering & Sorting**: filter (genre, tag, progress: not-started/in-progress/finished, has-ebook, etc.) and sort (title, author first-last / last-first, added date, progress last-updated/started/finished, sequence asc/desc).
- [ ] 4.7 Search: title/author/series client + server search; **podcast search accepts a term or an RSS feed URL**.
- [ ] 4.8 Item detail screen: cover, description (read-more/less), metadata, chapters, audio tracks, tags/genres/narrators, series links, "Play"/"Stream"/"Download"/"Read"/"Add to Playlist"/"Mark as Finished" actions.
- [ ] 4.9 Cover image caching (`cached_network_image`).

> 🤖 **Android checkpoint:** browse a real populated library end-to-end — long-list scroll perf, cover caching, filter/sort, both skins.

---

## Phase 5 — Audio Playback Engine (major milestone)

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
- [ ] 5.12 **Media-session foundation**: expose proper now-playing metadata + a playback queue through `audio_service` — the substrate the **CarPlay & Android Auto** browse trees build on in **Phase 10**. At this stage iOS already shows standard Control-Center/lock-screen now-playing, which also surfaces in CarPlay's Now-Playing screen automatically.
- [ ] 5.13 Lock/unlock player UI; keep-screen-awake toggle; MP3 index-seeking advanced option.

> 🤖 **Android checkpoint:** background playback + lock-screen controls survive screen-off, app-switch, phone-lock; volume-key nav; sleep-timer behaviors. (Full Android Auto browse UI is tested in Phase 10.)
>
> 🍎 **Xcode checkpoint 2 (major landmark):** iOS **Background Modes → Audio** entitlement, `audio_service` iOS config, silent-switch behavior, Control-Center/lock-screen controls (these auto-surface in CarPlay's Now-Playing; the full CarPlay browse experience comes in Phase 10). First point where iOS entitlements truly matter.

---

## Phase 6 — Offline Downloads & On-Device Local Media (major milestone)

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

## Phase 7 — Podcasts

- [ ] 7.1 Podcast library view (separate media type).
- [ ] 7.2 Episode list per podcast; played/unplayed/incomplete state; "# of episodes / N incomplete".
- [ ] 7.3 **Add podcast** flow (subscribe via server; search term or RSS URL) — "Podcast created" success/fail toasts.
- [ ] 7.4 **Auto-download episodes** setting per podcast.
- [ ] 7.5 Episode download + offline (reuses Phase 6 engine); delete local episode and delete-episode-from-server (with the destructive-action warning).
- [ ] 7.6 Latest/newest-episodes feed; new-episode indicators; next-episode action.

> 🤖 **Android checkpoint:** subscribe (by term and by RSS URL), enable auto-download, download an episode, confirm it flows through the shared playback/download engine with no special-cased bugs.

---

## Phase 8 — E-Books & Comics

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

## Phase 9 — RSS Feeds, Account, Settings, Stats, Polish

- [ ] 9.1 **RSS feed management**: open/close an RSS feed for a podcast or audiobook; feed slug, custom owner name/email, prevent-indexing toggle; show "RSS Feed is Open" state and feed URL preview. Include the HTTPS/PubDate warnings the app shows.
- [ ] 9.2 Account screen (user info, logout, switch server/user).
- [ ] 9.3 Settings, organized to match the reference app's taxonomy: **Playback**, **Data** (cellular), **User Interface** (haptic feedback, keep-screen-awake, lock-orientation, language, theme, bookshelf view), **Android Auto**, **Ereader**, **Sleep Timer**, **Advanced**, plus **Appearance/skin** from Phase 2.
- [ ] 9.4 **Stats**: minutes-listening 7-day chart, recent sessions, best day, daily average, days listened, streak ("in a row"), items finished, week listening.
- [ ] 9.5 **Year in Review** annual recap (show/hide).
- [ ] 9.6 **Logs / debug** screen (view/clear logs) for troubleshooting self-hosted connectivity — genuinely useful, mirrors `logs.vue`.
- [ ] 9.7 History screen.
- [ ] 9.8 **Localization**: wire up real translations (start with English; the pipeline exists from Phase 0.12/1.5). Language picker in UI settings.
- [ ] 9.9 Real app icon + splash (replace placeholders); consider an icon that reflects the coffee/book brand.
- [ ] 9.10 **Accessibility pass**: font scaling, screen-reader labels, and **contrast on the glass skin** (translucent surfaces over blur are a real contrast risk — verify text legibility).
- [ ] 9.11 Empty/error states across every screen (no server, empty bookshelf, no items/collections/series/bookmarks, failed download, no network).

> 🤖 **Android checkpoint:** full walkthrough — every screen, both skins, real server, real device; open/close an RSS feed; language switch; stats + Year-in-Review.

---

## Phase 10 — Car Integrations: CarPlay & Android Auto (final feature milestone)

The last committed feature set before release. Both platforms project a **browsable content tree** + a
**Now-Playing** screen onto the car head unit; playback commands route through the same `audio_service` handler
from Phase 5. Build the content tree once, then adapt it to each platform's API. Design for **driving reality**:
big tap targets, shallow menus, and downloaded/offline content must be browsable with no signal.

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

## Phase 11 — Stretch Goals (optional; only once core is solid)

- [ ] 11.1 **Chromecast** — Android-only in the reference app (CastManager/CastPlayer). Scope to Android; iOS has no cast support in the reference app, so not a parity gap.
- [ ] 11.2 Home-screen / lock-screen glanceable playback widget.
- [ ] 11.3 Tablet/foldable responsive layouts.
- [ ] 11.4 Additional community-style skins beyond the initial two.
- [ ] 11.5 Custom-time playback start ("start playback at HH:MM") and other power-user conveniences seen in the app.

---

## Phase 12 — Release Prep

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
- [ ] Libraries + switcher, books vs podcasts · 4.2
- [ ] Home shelves (continue listening/reading/series/books/episodes, recently added, newest, discover, listen/read again) · 4.3
- [ ] Bookshelf view vs modern grid · 4.4 / Phase 2
- [ ] Authors / Series (collapse series) / Collections / Playlists · 4.5
- [ ] Filter & sort · 4.6
- [ ] Search (incl. podcast RSS-URL search) · 4.7
- [ ] Item detail (metadata, chapters, tracks, tags, genres, narrators) · 4.8
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

These appear in the **server** README but are server/web-admin functions — BooksNeedCoffee consumes their
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

- **Three hard, platform-divergent milestones:** Phase 5 (background audio), Phase 6 (offline downloads + local media + sandboxing), and Phase 10 (CarPlay + Android Auto). Everything else is near write-once-run-anywhere in Flutter. Budget the bulk of your Mac/Xcode time around these three.
- **CarPlay has a long-lead dependency:** the Apple CarPlay audio entitlement (0.13) needs Apple's approval, so request it at the very start even though CarPlay itself is built last in Phase 10.
- **Test on Android continuously** (fast, no Mac trip); reserve **Xcode** for the milestone checkpoints in the cadence table, plus the early smoke test so iOS build breakage never surprises you late.
- Keep this file's checkboxes updated as you build — it doubles as a changelog and the parity ledger.
- If a feature turns out to depend on a server API you're unsure of, confirm the response shape against `~/Code/audiobookshelf` (server source) or https://api.audiobookshelf.org before implementing the client side.
