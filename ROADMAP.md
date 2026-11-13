# Steeped: Modern Audiobooks — Roadmap

A quick-glance status tracker. The only plan is [`PLAN.md`](PLAN.md); this file is the running log of what was
built and verified, plus the **To do** list for anything the automated run did not finish or test.
(Entries below that cite "`PLAN.md` Phase N" refer to the **old build plan**, replaced on 2026-11-10 by the
current `PLAN.md`; read the old one with `git show a9e7ad8:PLAN.md`.)

Platforms: **Android + iOS only.**

Status legend: ⚪ Not started · 🟡 In progress · 🟢 Done

| Milestone | Focus                                             | Phases        | Status |
|-----------|----------------------------------------------------|---------------|--------|
| 1         | Core streaming — connect, authenticate, browse, stream, basic UI | 0, 1, 3, 4, 5 | 🟢 done |
| 2         | Content, offline & downloads — downloads/local media, podcasts, e-books, account/settings/stats | 6, 7, 8, 9 | 🟢 done |
| 3         | UI customization & skins                          | 2             | 🟡     |
| 4         | Car integration — Android Auto & CarPlay          | 10            | 🟡     |
| 5         | Stretch goals & release prep                      | 11, 12        | ⚪     |

## Now

- Project renamed to **Steeped** ✅
- Plan reorganized into the 5 milestones above ✅
- Phase 0 tech-stack decisions locked in ✅ — CarPlay entitlement requested from Apple, **awaiting approval**
  (0.13 — will nudge you again as Milestone 4 approaches)
- Phase 1 skeleton built ✅ and verified on-device ✅.
- Phase 3 (Server Connection & Authentication) built ✅ and verified end-to-end ✅ against evan's real
  Audiobookshelf server on the Pixel 8 Pro: connect → login → session persists → socket.io "Live" status.
  Corrected Phase 0.4 along the way — the server uses socket.io, not a raw websocket. 3.3 (multi-server
  switcher) and 3.8 (mask-address toggle) deliberately deferred — see `PLAN.md` Phase 3 for why.
- Phase 4 (Library Browsing) built ✅ and verified end-to-end ✅: library switcher, personalized home
  shelves (generic-by-type renderer, no hardcoded rows), full 60-item library grid with infinite scroll,
  item detail with real metadata/cover/progress — all confirmed against evan's real library. 4.5
  (authors/series/collections/playlists screens), 4.6 (filter/sort UI), 4.7 (search) deliberately deferred
  — see `PLAN.md` Phase 4 for why.
- Phase 5 (Audio Playback Engine) built ✅ and verified end-to-end ✅ on the Pixel 8 Pro: real streaming
  (direct play only, no transcode), mini-player + Now Playing, background playback, lock-screen/notification
  controls with a working system media-control card, chapter seeking, speed control, progress sync,
  mark-finished. 5.7 (sleep timer), 5.8 (bookmarks), 5.11 (volume keys), 5.13 (advanced player settings)
  deliberately deferred — see `PLAN.md` Phase 5 for why.
- **Milestone 1 is done.** 🎉
- Now working in the `milestone-2-offline-downloads` branch, pushing more frequently since `main` holds the
  stable Milestone 1 build.
- Phase 6 (Offline Downloads & On-Device Local Media) built ✅ and verified end-to-end ✅ on the Pixel 8
  Pro: downloaded a real 12h38m book via `background_downloader` with live progress, then **genuinely cut
  wifi + cellular data** and confirmed it plays fully offline (position/chapters tracked correctly) — not
  just "implemented," actually tested with no network path available. Found and documented a real gap along
  the way: cold app start while offline currently fails before reaching downloaded content, because
  session bootstrap (Phase 3) doesn't distinguish "network unreachable" from "token actually invalid."
  6.2 (series download), 6.8 (local-media folders), 6.9 (cellular controls), 6.10 (storage management), and
  a durable offline-sync retry queue (6.7) deferred initially — **all closed out 2026-08-01, see below.**
- **Phase 6 fully closed out (2026-08-01)**, driven live over adb per item: **6.10 storage management**
  (total/per-item download size, low-storage warning against real free device space via a native `StatFs`
  channel, bulk-delete — verified against a real 292MB download and a 1.5GB 4-item batch); **6.7 durable
  sync queue** (failed progress syncs now persist to drift and flush on reconnect, verified surviving a real
  force-stop + cold relaunch while still offline); the **cold-start-while-offline session bug** from Phase 6
  (session bootstrap now falls back to the cached session on a connectivity failure instead of logging out —
  verified live, downloaded content stayed reachable after a cold offline relaunch); **6.2 series download**
  (reuses the existing items-filter endpoint, no series-browse UI needed — verified downloading all 3 Thrawn
  Trilogy books from one tap); and **6.8 local media** (single-file import rather than a folder scan — see
  `PLAN.md` Phase 6.8 for why — verified importing, playing, and deleting a real file with zero network
  calls). Also found, while investigating what's actually still blocked: server source
  (`~/Code/audiobookshelf`) turned out to already be on this machine, so 7.3/7.4/delete-episode-from-server
  were re-verified against real source + a new Account-screen permission check — they're genuinely
  permission-blocked (evan's account can't update or delete), not source-blocked as previously written.
- **Bug fix (2026-07-31, reported by evan)**: a downloaded book wasn't resuming from its saved position.
  Root cause: the progress-sync timer only stopped via in-app pause, not hardware/notification pause (which
  calls the audio handler directly) — it kept ticking in the background and, once connectivity returned from
  the Phase 6 offline test above, synced a stale near-zero position to the real server, silently overwriting
  real progress. Fixed by tying the timer to actual playback state instead. **This did corrupt real progress
  on evan's server for one book during testing**; repaired using the still-intact progress percentage.
  Verified fixed: resumes correctly now. See `PLAN.md` Phase 5.9 for details.
- **Follow-up verification (2026-07-31, requested by evan)**: confirmed reconnect-while-playing actually
  uploads progress — played a downloaded book, went offline, let it advance, reconnected *without pausing*,
  and confirmed via the server's raw response that the new position uploaded within one sync tick. Also
  confirmed a downloaded item is always preferred over streaming, online or not. Found and fixed a second,
  smaller display bug along the way: the server's `progress` percentage field doesn't get recomputed by our
  sync calls (only `currentTime` does), so the item detail screen's "% complete" could drift stale — now
  computed client-side from `currentTime`/`duration` instead. See `PLAN.md` Phase 6.7 for details.

- Phase 7 (Podcasts) built ✅ and **verified end-to-end ✅ on the Pixel 8 Pro** (2026-07-31), driven live over
  adb (build → install → `input tap`/`screencap`, not just launched) against evan's real podcast library
  ("Living with Harry Potter," BBC Radio 4). Podcast detail renders a real episode list with correct
  played/unplayed/incomplete state (progress merged from `GET /api/me`); downloaded a real episode (~56MB
  file + cover landed on disk under a composite `podcastId::episodeId` path — **reusing the Phase 6 download
  engine unchanged**, no drift schema change needed); played it **fully offline from the local file** with
  real decoding and advancing position; deleted the local download and confirmed the file was actually gone
  and the shared Downloads list correctly dropped the entry with no orphan row. The "Latest Episodes" feed
  (`/recent-episodes`) was confirmed against the real server response shape — evan's library only has one
  (2005-era) episode, so the feed's "No recent episodes" is a genuine empty state, not a bug. Deferred, with
  reasoning in `PLAN.md` Phase 7: **7.3 add-podcast** and **7.4 auto-download** (confirmed 2026-08-01 as
  genuinely permission-blocked — `POST /api/podcasts` is admin-only server-side and evan's account is
  non-admin), plus **delete-episode-from-server** (confirmed permission-blocked too — needs `canDelete`,
  which evan's account doesn't have) and the minor new-episode-indicator / next-episode niceties from 7.6.

- Phase 8 (E-Books & Comics) built ✅ and **verified end-to-end ✅ on the Pixel 8 Pro** (2026-07-31), driven
  live over adb against evan's real eBooks and Comics libraries. Read a real 44MB illustrated EPUB (Harry
  Potter — A History of Magic) end-to-end: TOC, chapter jump, real embedded illustrations, live reading
  settings (font/theme/size/spacing), progress sync (confirmed it landed in the "Continue Reading" shelf —
  which needed **zero new code**, since the personalized-shelves renderer from Phase 4.3 was already generic
  by shelf type). Read a real 128MB/16-page CBZ (The Legend of Genji) end-to-end: resumed at the correct
  saved page, paged through multiple real pages, extraction ran off the UI thread with no jank.
  **Two real crashes/bugs were found and fixed via this on-device testing, not caught by `flutter analyze`:**
  (1) `epub_view`'s built-in image-tag handler crashes the entire reader body (no per-item error boundary) on
  any `<img>` whose `src` doesn't exactly match its internal map — fixed with a custom safe chapter builder;
  (2) an `InteractiveViewer` added for comic pinch-zoom silently broke all page-swiping by claiming the
  gesture from the arena before `PageView` could see it — `panEnabled: false` looked like a fix but wasn't
  (it only suppresses the pan, not the gesture claim), so `InteractiveViewer` was dropped entirely in favor
  of reliable paging. See `PLAN.md` Phase 8.1/8.4 for the full detail on both.
  **PDF reader (8.3) is built but not verified on-device** — no confirmed PDF-format item exists in evan's
  library to test against. 8.5 (primary/supplementary ebook) and 8.6 (send-to-device/Kindle) deliberately
  deferred — see `PLAN.md` Phase 8 for why.

- Phase 9 (RSS Feeds, Account, Settings, Stats, Polish) built ✅ and **verified end-to-end ✅ on the Pixel 8
  Pro** (2026-07-31), driven live over adb against evan's real account. Two real endpoints confirmed live
  before building: `GET /api/me/listening-stats` (the `/api/me/stats` guess 404s) and
  `GET /api/me/listening-sessions`. Built and verified: **Account** screen (real user/server data),
  **Settings** with every toggle wired to real behavior — jump interval, scale-elapsed-by-speed, cellular
  stream/download controls (enforced via `connectivity_plus`), haptic feedback, keep-screen-awake
  (`wakelock_plus`, confirmed persists across navigation), lock-portrait, a language picker (English only —
  honestly scoped, no other ARB translations exist), the Ereader panel (now shared between Settings and the
  Phase 8 reader via one provider), and a real **Sleep Timer** (5.7, previously deferred — manual duration,
  confirmed live: started, icon filled, cancelled, icon reverted, playback unaffected). **Stats**: real 7-day
  chart + best day/streak/average/items-finished, verified against evan's real account (573 days listened
  all-time, 6-day streak, 63 items finished). **Year in Review**: client-side aggregation of the same stats
  data (no dedicated annual endpoint exists). **History**: 1228 real sessions, verified paginated
  infinite-scroll. **Logs**: a real drift-backed debug log hooked into actual failure paths (session
  refresh, progress sync, downloads) — confirmed showing a genuine empty state (nothing failed this
  session). **9.1 RSS feed management deferred** — `GET /api/feeds` returned a real 403 against evan's
  account (`type: user`, `permissions.update: false`), confirming it's admin-gated server-side; the Settings
  screen correctly hides the RSS section for non-admin accounts rather than showing a feature that would
  always fail. **9.9 real app icon deferred** — no branding artwork exists yet, and the icon-generation
  tooling was already removed from `pubspec.yaml` in Phase 8 for a real dependency conflict with the EPUB
  reader. See `PLAN.md` Phase 9 for full detail.

**Milestone 2 is done.** 🎉

- **Milestone 3 (Phase 2 — Design System & Theming Engine) started 2026-08-01** on a new
  `milestone-3-ui-skins` branch. Built and **verified live on the Pixel 8 Pro**: the `Skin` abstraction
  (2.4) with two real, distinct skins — **Glass Modern** (2.2, new default: cool-blue dark palette,
  translucent cards, and a genuine `BackdropFilter`-blurred app bar, confirmed live scrolling content
  visibly blurs underneath it) and **Bookshelf** (2.3: warm wood-brown palette, opaque cards, sharper
  radii, procedural book-spine cover shading — no literal wood/paper texture image, since no branding
  artwork exists yet). A live Settings → Appearance switcher (2.6) — tapping a skin re-themes the whole
  app instantly, persisted across restarts, verified switching both directions. The library grid (2.7) now
  genuinely diverges per skin (spine shading vs. plain modern cards), confirmed against evan's real 60-item
  library. A light accessibility pass (2.8): a semantic label on the skin cards, spot-checked 1.3x system
  font scale with no clipping — not a full audit. **Still open**: 2.5 (a real shared skin-aware component
  library — today only stock Material widgets pick up per-skin `ThemeData`, most other screens haven't been
  retrofitted beyond that), light/dark/black brightness variants per skin (each skin ships one fixed
  dark-first palette only), and a deeper 2.8 accessibility pass (formal contrast-ratio check on the glass
  skin's translucent cards, a broader screen-reader-label sweep). See `PLAN.md` Phase 2 for full detail.
  Real design-system work like this carries a lot of subjective taste — the exact palettes, blur strength,
  and whether Bookshelf should later get literal textures are open questions for evan to weigh in on, not
  settled by this pass.

- **Bug fix (2026-08-01, reported by evan: "auth fails randomly")**: the socket "Live" badge would
  permanently get stuck on "Auth failed" after the access token expired, because `SocketService` kept
  re-sending a stale token captured at connect time on every reconnect — including the ones
  `socket_io_client` triggers automatically after a network blip, which happen often enough over a real day
  that this wasn't a rare edge case. Fixed to always use a fresh token and to force a real token refresh on
  a genuine auth failure. Verified live: reproduced the permanent-stuck bug on the old build via a wifi
  toggle, confirmed the fixed build recovers automatically. See `PLAN.md` Phase 3.6 for full detail.

- **Bug fix (2026-08-02, reported by evan: one comic failed to load while another worked)**: a comic
  ("The Apothecary Diaries: Volume 01") whose reading progress had ever been written by another client threw
  a type-cast crash on its item detail screen, because that client wrote the CBZ page-index `ebookLocation`
  as a raw JSON number instead of a string. Fixed by coercing instead of casting in `MediaProgress.fromJson`,
  plus the same defensive fix for two other server fields with the identical numeric-`ino` risk. Verified
  live: the comic now opens and reads correctly. See `PLAN.md` Phase 8 for full detail.

- **Milestone 4 (Phase 10 — Car Integration) started 2026-08-01**, on the same `milestone-3-ui-skins` branch
  (picked up out of strict milestone order, at evan's request to "continue onto the next phase"). Built the
  shared car content-tree foundation (10.1–10.3) and the Android Auto side of it (10.4, 10.6): a real
  browsable tree (Downloaded/Local Media/Continue Listening/Libraries → items, podcasts → episodes),
  wired into `audio_service`'s `MediaBrowserService`, with the `automotive_app_desc.xml` manifest
  declaration Android Auto specifically requires. Installed the Desktop Head Unit and got it to a real
  "connected" state over ADB — confirming the phone accepts Steeped as a car media source — but **couldn't
  visually drive or screenshot the DHU's own window in this environment** (no working desktop screenshot
  tool, and installing `xdotool` needed a sudo password that wasn't available). Verified the underlying
  logic directly instead: temporary debug logging (reverted after use) exercised the real
  `getChildren`/`playFromMediaId` methods against evan's real account — confirmed the correct tree, all 4
  real libraries, a podcast correctly branching into its episode list, and a full playback dispatch that
  actually started real audio (confirmed both via `playbackState.playing=true` and visually in the app's own
  mini-player). Found and fixed a real bug this way: "Continue Listening" depended on a provider that stays
  null until a user manually touches the in-app library picker, so it silently returned empty for most real
  sessions, not just a first-launch edge case. **Still open**: an actual visual pass through the DHU (or a
  real car) once screenshot/input tooling is available, 10.5 (Android-Auto-specific settings), a full
  Android-for-Cars content/quality guideline audit, and all of CarPlay (10.8–10.12, Mac-gated). See
  `PLAN.md` Phase 10 for full detail.

- **Library browsing follow-ups landed 2026-08-26 (requested by evan)**: "Recent Series" home-shelf cards
  now show real cover art (the series' first book's cover) instead of a plain text box — 4.5's series slice
  is done, closing that specific gap while Authors/Collections/Playlists stay deferred. Added a dedicated
  Series tab and series-detail screen, backed by a real `GET /api/libraries/:id/series` endpoint (confirmed
  live, not previously used anywhere in the app). Restructured the home screen into `[Home | Series |
  Library]` top tabs (`TabBar`/`TabBarView`, no go_router shell-route rework) — "Browse Full Library" is
  now the Library tab itself rather than a button; podcast libraries get `[Home | Library]` since series
  don't apply. Also shipped 4.7's Books + Series search (a search icon on the home app bar, debounced
  query, grouped results) — Authors/Narrators/Tags/Genres categories still deferred, no browse screens to
  link into yet. Verified end-to-end against the public `audiobooks.dev` demo server via the Linux
  integration-test harness (see `linux/README.md`) — connect → login → Series tab → series detail → search,
  all real network calls, no mocks. See `PLAN.md` Phase 4 (4.5, 4.7, 4.10) for full detail.

- **Bug fix (2026-09-30/10-01, reported by evan: iOS sessions logging out after extended idle periods)**:
  `AuthInterceptor`'s refresh-failure handling treated *any* error from `/auth/refresh` — including a plain
  network timeout — as proof the session was dead, wiping the stored session on nothing more than a
  bad-signal moment. Fixed to only force logout on a definitive rejection (a real 401/403 from the refresh
  call itself, or no refresh token in storage); any other error now leaves the session alone, matching the
  distinction `SessionController`'s cold-start bootstrap already made. Also removed `SocketService`'s own
  active refresh-and-retry loop (the one added in the 2026-08-01 fix above) — it could fire a refresh from
  an arbitrary background moment, which iOS suspending the app mid-request could turn into a permanently
  dead refresh token (the server rotates the token on every use regardless of whether the client ever sees
  the response). Socket recovery now works the way the reference app does it: a successful REST-401 refresh
  re-authenticates the existing socket as a side effect, rather than the socket chasing its own refresh.
  Cross-checked against a cloned copy of `AudioBooth` (a native Audiobookshelf iOS client) for comparison.
  **Not yet verified live** against the original multi-day iOS pattern — needs real on-device idle time to
  confirm. See `PLAN.md` Phase 3.4 and 3.6 for full detail.

- **Bug fix (2026-10-01, reported by evan: mini-player occasionally got permanently stuck, no errors
  anywhere)**: a forced logout while Now Playing was open could strand the mini-player's open/closed guard
  at `true` forever, because the guard only cleared on a route *pop* and a forced-logout redirect replaces
  the navigation stack instead of popping it. Fixed by deriving the guard from the router's actual current
  state (whether `/now-playing` is still present in its route stack) instead of tracking it by hand, so it's
  correct no matter how the route leaves the stack. **Not yet verified live** — needs an on-device repro.
  See `PLAN.md` Phase 5.2 for full detail.

## Quality-of-life pass (branch `qol-features`, 2026-10-07)

Everything in `PLAN.md` that doesn't need admin permissions or a Mac, done in the plan's order. All
uncommitted. Verified on Linux (unit/widget tests plus integration tests against audiobooks.dev and a
second local Audiobookshelf); **audio behaviour is unit-tested only and still needs a phone check**.

- **A Settings:** separate jump back/forward lengths (old single value migrates), cellular Always/Ask/Never
  (old bools migrate), mask server address, hide Download without permission, lock-screen seek toggle.
- **B Playback:** auto-rewind on resume (with optional scaling), sleep timer end-of-chapter, fade-out,
  30-second chime, quick extend/restart, automatic night window.
- **C Progress:** discard progress, sync-failed badge + "Retry now".
- **D Library:** remembered section, has-ebook filter, go to author/series, quick actions on shelves and the
  item page, author page in reading order, collapse series.
- **E1/E2:** metered label + "treat metered Wi-Fi like cellular"; multiple servers/accounts with a
  first-launch migration of the old session into profile #1, a pre-upgrade database backup, per-profile
  tokens/downloads/queued progress/search history, switcher in the Home app bar and Account screen, grouped
  Downloads screen.
- **F:** light/dark/black/follow-system variants per skin, accessibility pass (contrast tests, tooltips,
  large-text overflow fixes), native splash, translation setup (en-US only, `lib/l10n/README.md`),
  Android Auto settings + "play <book>" voice search.

Not verified: sleep fade/chime and auto-rewind by ear, Android 12 splash and metered detection on a device,
Android Auto/Assistant, iOS launch screen, E2 on a phone. Known gaps: car-tree titles and notification
action labels aren't localized; `ServerProfile` removal while that account is playing downloads from another
server was reasoned about, not exercised.

## Next

- Two parallel threads are open — Milestone 3 (skins) and Milestone 4 (car integration) — pick up either:
  - Milestone 3 Phase 2: 2.5 (shared component library), brightness variants, deeper accessibility audit.
  - Milestone 4 Phase 10: an actual DHU visual pass (needs desktop screenshot/input tooling — `xdotool`
    install needs a sudo password), or move on to CarPlay groundwork once on the Mac.
- **Mini-player polish, logged 2026-08-02 (evan) — all four items now built and verified live 2026-08-02.**
  See `PLAN.md` Phase 5.14–5.17.
- **5.14 built**: every Play-triggering row/button (item detail, downloads, local media, podcast episodes,
  recent episodes) now shows a small spinner and disables itself while loading, instead of looking
  unresponsive during the fetch-then-buffer gap before audio starts, and only navigates to Now Playing if the
  load actually succeeded. Caught a real bug along the way: `just_audio`'s `play()` doesn't resolve until
  playback stops, so the pre-existing `await _handler.play()` would have left the new indicator stuck on for
  the whole listening session — fixed by not awaiting it. Verified live on the Pixel 8 Pro against a real
  streaming book. See `PLAN.md` Phase 5.14.
- **5.15/5.16/5.17 built together** (they're all the same `MiniPlayer` widget): the mini-player is now a
  floating, elevated card (margin, rounded corners, real shadow) instead of a flat edge-to-edge bar, with an
  expand chevron and its own rewind-30/forward-30 buttons alongside play/pause. Made skin-aware for free by
  reusing the existing Phase 2.2 `GlassSurface` widget — Glass Modern gets a genuinely frosted/blurred card,
  Bookshelf gets an opaque one. Verified live in both skins on the Pixel 8 Pro, including confirming the jump
  buttons work from the collapsed bar without triggering the bar's own expand-tap. **Follow-up tweaks same
  day (evan's feedback after seeing it live)**: chevron moved from centered-above to left of the cover as a
  real `IconButton` matching play/pause's size/style (36px), and the rewind/play/forward icons sized up
  generally — both re-verified live. See `PLAN.md` Phase 5.17 for full detail.
- **Chapters/Tracks toggle on Now Playing, built 2026-08-02, requested by evan**: a `SegmentedButton` lets
  you switch between a book's chapter list and its raw underlying audio-file tracks, only shown when the two
  would actually differ. Required adding the real per-track filename (`title`) to the `AudioTrack` model,
  which wasn't being parsed before. Verified live against a real 2-file book — the Tracks tab showed the
  actual filenames, seeking to a track worked and updated the highlighted row. **Follow-up (2026-08-03)**:
  gated behind a new Settings → Playback "Show Tracks tab" toggle, off by default — with it off, Now Playing
  behaves exactly as it did before this feature existed. See `PLAN.md` Phase 5.5 for full detail.
- **Chapter/Book time display, built 2026-08-03, requested by evan**: Now Playing's time row can show
  chapter-relative time, book-relative time, or both at once — mirroring the reference app's behavior, with
  "at least one must stay on" enforced by `SegmentedButton` itself rather than hand-rolled validation.
  Defaults to book-only (identical to the screen's look before this existed). Changeable both from Settings
  → Playback and a new quick-access sheet on Now Playing (shared `TimeDisplayModeSelector` widget, same reuse
  pattern as the ereader settings panel). Verified live against a real book with chapters (Dune) — all three
  modes, plus independently confirmed the chapter-relative math is correct and that the last remaining option
  genuinely can't be turned off. See `PLAN.md` Phase 5.5 for full detail.
- **iOS Xcode smoke checkpoint partially cleared 2026-08-04**, on Emma's MacBook Pro — the iOS shell now
  builds and launches on the Simulator, closing the last open item from Phase 1's original testing cadence
  plan. Not a quick win: `ios/Podfile` turned out to have never existed in this repo at all (git history
  confirmed it, not just missing locally), `background_downloader` needed a deployment-target bump from
  13.0 to 14.0, `Debug.xcconfig`/`Release.xcconfig` were missing the CocoaPods include lines, a local
  `xcode-select` misconfiguration broke a plugin's native-asset build hook, and a stale DerivedData cache
  needed a full clean before everything lined up. All of that is machine/environment setup, not app code —
  the only Steeped-side changes were the Podfile itself, the deployment-target bump, and the two xcconfig
  includes. Remaining build warnings are entirely inside third-party plugin source (deprecated iOS APIs),
  not Steeped's own code. **Deliberately not marking this "done"**: no full iOS functional walkthrough yet
  (login/library/playback — only Android has been verified end-to-end), no real-device test, and — much
  later — no App Store review approval yet either. See `PLAN.md`'s Phase 1 checkpoint note for full detail.
- Still worth a look next time on-device: confirm a real PDF item exists somewhere in evan's library to
  close out Phase 8.3's verification gap; verify Phase 9's cellular controls against a real cellular-only
  connection (needs airplane mode + manually re-enabled mobile data).
- Whenever real app-icon artwork exists: revisit Phase 9.9, including whether `epub_view`'s `image` ^3.x
  pin still blocks `flutter_launcher_icons`/`flutter_native_splash`.

## Run log (PLAN.md automated run, started 2026-11-11)

Emulator: AVD `steeped_test` (Android 35, headless, `-gpu host`), debug APK from the `qol-run` worktree, demo server
audiobooks.dev. Audio output is off, so playback is not audible. The demo server has only EPUBs (5, one an EPUB3 Media
Overlay) and no PDF or comic items, so PDF and CBZ checks are blocked there.

- **V1 verified:** emulator boots, APK installs and launches, login works, library switcher and Books library load.
- **V3 EPUB reader, partly verified on the emulator:**
  - Opens and renders; header, footer scrubber, chapter label and percent show.
  - **Bug found and fixed:** edge taps never turned the page and the middle tap never toggled the bars, because the
    EPUB body's `SelectionArea` won the gesture arena against the reader's tap handler. Taps are now read from raw
    pointer events (`reader_chrome.dart`). Verified: right-edge tap advances; regression tests added
    (`reader_chrome_test.dart`).
  - **Bug found and fixed:** progress jumped to 100% after one page turn because the book length was guessed from the
    table of contents. It now uses the real paragraph count. Verified: 0% after one turn at the start.
  - **Fixed:** a finished book's button said "Continue reading (100%)"; it now says "Read again". Verified.
  - **V4 sync and resume verified on the emulator (EPUB):** the position is sent to the server every 20 s and on
    leaving the reader (the item page's progress bar changed after reading). Note the demo server gives every login
    its own guest account, so check server state from the app, not from a separate curl login.
  - **Bug found and fixed:** reopening could land on the first screen. `epub_view` writes the first spine item as
    `/6/0[...]` and cannot parse it back (it swallows the error), so the saved position was ignored. The reader now
    falls back to the saved fraction when the position does not land. Verified: left at ~1%, reopened in the same
    part of the book (approximate: it resumes at the saved paragraph, not the exact scroll offset).
  - **Fixed:** a re-read of a finished book showed "Read again"/100% because the server keeps `isFinished`; the item
    page now trusts the reading position once there is one. The server flag itself stays set (PLAN.md J0).
  - **Fixed (cosmetic):** header and footer bars were 96% opaque and let text show through; now opaque. Rebuild to
    confirm.
  - **Resume of a position written by the official app verified** (Frankenstein, 11%, epub.js CFI).
  - **Verified on the emulator:** bookmark toggle, persisting across reopening, bookmarks sheet; contents sheet;
    reading settings panel renders (mode, tap-to-turn, keep screen on, brightness, font, size, spacing, justify,
    margins, theme).
  - **Bug found and fixed (highlights never worked):** text drawn by `flutter_html` inside a list cannot be
    selected by `SelectionArea` (confirmed with a widget test), so the long-press did nothing. Plain-text
    paragraphs (only text and inline formatting) are now drawn as selectable rich text
    (`selectable_paragraph.dart`); images, headings, lists and tables still use `Html` and are not selectable.
    Verified on the emulator: long-press selects a word and shows Copy / Share / Select all / Read aloud /
    **Highlight**; Highlight paints it and lists it under Highlights.
  - **Bug found and fixed:** the highlight was painted on the first matching paragraph near the reader's position
    rather than the one selected. It now uses the on-screen position of the selection. Verified on the emulator
    (selected the second "mind" of two in adjacent paragraphs; the highlight landed on it). Highlights also persist
    across leaving and reopening the book.
  - **Bug found and fixed (cross-app sync):** `epub_view` writes every saved position as `/6/0[<anchor>]`, which
    is not a real spine position, so the official app and AudioBooth could not resume from a position this app
    wrote. The package step is now rewritten from the book's spine (e.g. `/6/16[item9]!/4/2[pgepubid00007]/8`).
    Verified in the app's database on the emulator. NOT verified: that the official app actually opens at that spot
    (needs the official app or a second client); bookmarks created before this fix keep the old value.
  - **Resume hardened:** if the saved position lands more than 8 points from the saved fraction (or at the very
    top), the reader jumps by the fraction instead.
  - **Bug found and fixed:** the footer/bookmark chapter label stayed on the first chapter ("THE FULL PROJECT
    GUTENBERG LICENSE") deep into a book; it now comes from the table of contents. Verified ("Chapter 1").
  - **Known limits:** a word that occurs twice in the same paragraph highlights the first occurrence; headings and
    paragraphs with images are not selectable; link taps in the new renderer are kept but untested on device.
  - Still to check: scrubber drag, scroll mode, Light/Black themes, highlights surviving reopen.
- **V2 stuck-header fix verified on the emulator.** A stand-in server (forwards to the demo server, but returns no
  libraries or a 500 for `/api/libraries`) reproduced the half-configured server: the empty state shows
  "No libraries on this server." and the failed state shows the error with Retry and View Downloads, both with the
  account, settings and log out buttons in the header; log out returns to "Connect to Server". The failed state's
  raw error text ran edge to edge; it is now padded and centered (not re-checked on the emulator).
- **V6:** `flutter test` (234 tests) and `flutter analyze` (no errors; 22 existing deprecation notices) pass.
- **Pages/Scroll switch verified by unit test; emulator re-check pending:** changing the mode while reading did
  nothing until the book was reopened; `PagedScrollBehavior.shouldNotify` fixes it (test fails without the fix).
- **Scrubber verified:** tap to 50% jumps to "Chapter 14 - 50%". Light theme verified; Black not looked at.
- **H7 verified on the emulator:** an ebook-only item (Pride and Prejudice) shows only "Read again" (no disabled
  Play); an audiobook still shows Play and Download. Still showing Play: the "Play all" buttons on series and
  collection pages when every book in them is an ebook (not changed).
- **Noticed, not fixed:** an audiobook's description shows raw `<br />` tags, and its details line ends with a
  stray "· 0" (probably an empty published year).
- **Phase I (listening sessions) was already built; verified on the emulator:** `/play` -> `sync` -> `close` against
  the demo server raised today's listening stats and created a History session, and the item's progress moved with
  it (so the session sync and the progress PATCH write the same value). In the app, ~1 minute of playback (the emulator
  plays silently) created a History row, today's bar, "Days listened 1" and "Current streak 1 day". The server's day
  key (2026-11-12) was ahead of the local date (11-11) and the Stats chart still placed it on today.
  The account menu ("Add server or account", "Manage accounts") and the Settings screen (separate jump lengths,
  lock-screen seek, auto-rewind) render. Not checked: the offline session queue (needs airplane mode), audio-dependent
  behaviour.
- **Plan correction:** the old sessions plan I merged in had gone stale; Phase I was marked unbuilt in error.
- **Audit of "not built" items against the code (2026-11-11):** already built, not re-verified on the emulator: K1 audio
  bookmarks, K2 search by author/narrator/genre/tag, K8 keep-screen-awake setting, the Stats streak count. Genuinely
  not built: K7 (custom-time start), K9 (changelog), G1-G6 reading streaks and Home chip, H8-H10, Phase J. Unknown:
  K4 widget, K5 tablet layouts, K6 more skins, K10 shared widgets (not found in code).
- **J0 built:** the readers now send `isFinished: true` only when the item has no audio (`ebookFinishedFlag`), so
  finishing the ebook half of a combined item no longer marks the audiobook finished. Not covered: the server itself
  clears `isFinished` when audio progress moves on an item whose flag was set by the ebook (server behaviour; the
  client can't prevent it). No combined audio+ebook item exists on the demo server to try it on.
- **Known, not fixed:** the disabled Play button still shows on ebook-only items (PLAN.md H7).
- **Blocked on the demo server:** PDF reader, comic (CBZ) reader. Needs a library with those formats.

### Phase J: linking (J1-J4), built and checked on the emulator 2026-11-12

- **Built:** `ItemLinks` stored in the existing key-value table (one JSON list per server profile, no schema bump),
  ASIN -> ISBN -> author + title matching (`link_matching.dart`), `SyncStrategy` with Off and Estimated
  (`sync_strategy.dart`: chapter-title match, interpolation inside the chapter, overall-fraction fallback), EPUB chapter
  spans by text length, a "Linked books" setting (Off / Estimated), and a link row on single-format item pages
  (suggest, confirm, Read/Listen, unlink). 31 new unit tests; suite passes.
- **Emulator:** the demo server has no ebook/audiobook pair with matching titles, so a local proxy
  (`link_proxy.py`) relabelled "Pride and Prejudice" as "First Fifty Digits of Pi" / Scott Hemphill. Verified: the
  suggestion dialog lists it ("Matched by author and title"), confirming saves the link, the row shows "Linked
  ebook", and Read opened the reader at 65% (the audiobook's 65%) through the fraction fallback.
- **Listen direction verified:** the new headphones action in the EPUB reader, with the reader at 30%, started the
  audiobook at 16:11 of 53:42 and opened Now Playing.
- **Not verified:** chapter-title matching on a real pair; ASIN/ISBN matches on a real server (the demo has neither). Switching from Now Playing
  (J2) is not built; the reader has the Listen action, PDF/comic readers do not. Linked progress is written by each reader's/player's normal sync after the
  switch, not as a separate write.
- Precise mode (J5/J6) not started; `precise` currently behaves as Estimated and is not offered in Settings.

### Phase G: streaks (G1-G5), built and checked on the emulator 2026-11-12

- **Built:** `computeStreak` (pure; listening + reading merged, goal threshold, one forgiven miss per 7 days and never two
  in a row, weekly mode, server-timezone anchor), per-profile reading seconds in the key-value table (no schema
  bump), a `ReadingClock` (idle gaps over 2 min earn nothing) wired into the EPUB, PDF and comic readers, a flame chip
  in the Home bar (outlined while today is empty; tooltip shows forgiven days and the at-risk hint), a Streaks section
  in Settings (show chip, daily bar, forgive, weekly), and Stats now uses the merged streak plus a Longest streak tile.
  16 streak tests + 5 reading-clock tests.
- **Bug found by the emulator and fixed:** the clock floored every sub-second gap to 0, so scrolling earned about
  2 s. A test now fails without the fix. After it, about 85 s of reading credited 81 s.
- **Verified:** chip shows after playback (1), Stats shows Current and Longest streak, reading seconds land in the
  database for the active profile.
- **Not verified / cost:** the chip squeezes the library name in the Home bar further ("Au..." on this 1080 px
  emulator); consider moving it. Milestone toast (7/30/100/365) and the at-risk banner are not built (the at-risk state shows in
  the chip's tooltip only). The reserved reminder settings keys are not added. G6 (server reading sessions) not spiked.

### Home bar changes, checked on the emulator 2026-11-12

- Library picker shows the server's icon (Material mapping in `library_icon.dart`): icon only when collapsed, icon +
  name in the list. The Live badge lost its (metered)/(cellular) suffix and the "Show network type" setting was
  removed. Account, Search, Downloads and Settings moved into one hamburger menu at the top right. This also fixed
  the squeezed library name noted under Phase G.
- The streak chip now always shows: a dimmed flame with 0 when there is no streak (checked on the emulator by raising the daily bar to 60 min).
- The emulator showed "Offline" only because the login still pointed at the link proxy, which was stopped.

### Linking on the real server (Alchemised), 2026-11-12

- **Reported:** Alchemised (audiobook in "Audio Books", ebook in "eBooks", both titled Alchemised by SenLinYu) would not
  link; the dialog said "No matching book found". Reproduced on the emulator against the real server.
- **Cause (probable):** the matching itself was fine for identical metadata, so the other-format filter was rejecting the
  ebook: a search result only counts as ebook-only when `numAudioFiles` is 0, and search results on that server do not
  carry it (it defaulted to "has audio"). Now `hasAudio` falls back to the `audioFiles`/`tracks` lists and `hasEbook` to
  `ebookFile`. Not confirmed by reading the raw response (no credentials used), but the fixed build links it.
- **Also changed:** titles match on the part before a subtitle, authors ignore spaces ("SenLinYu" = "Sen Lin Yu"), and the
  link dialog has a "Search by title" box for books the rules miss.
- **Verified on the emulator:** the suggestion "Alchemised, SenLinYu, Matched by author and title" appears and the link
  saves ("Linked ebook"). Read/Listen were not pressed on the real server, because they write progress there.

### EPUB reader showed only chapter headings (Alchemised), fixed 2026-11-12

- **Cause:** `epub_view` builds pages only from the table of contents. Alchemised splits every chapter into
  `chapterNNN_split_000.xhtml` (the heading, 802 bytes) and `_split_001.xhtml` (the text) and lists only the heading, so
  the text was dropped (the book's text was 83 KB instead of 2.5 MB).
- **Fix:** `epub_loader.dart` appends the spine files a contents entry is followed by (and that the contents do not list)
  to that entry. Used by the reader and by the linking chapter spans (which had been sizing chapters by their headings).
  Checked on the real file and in the reader: chapter 68 text now shows, at the position mapped from the audio.
- **Known limit:** positions written to the server (CFIs) for text inside a merged file point at the chapter's heading
  file, so another app resuming from them lands at that chapter start, not the exact paragraph. Front matter before the
  first contents entry is still not shown.
- **Also fixed:** the book page now refetches its progress when Now Playing closes, when playback starts or stops,
  so a rewound book no longer keeps saying "Finished" (checked: it now shows "84% complete").

### Streak extras, reminders, ebook queue and other fixes, built 2026-11-12

- **G5 done:** a 7-day dot row under the Stats tiles, a dismissible at-risk banner on Home (from 5 pm, only with a streak
  running and today empty), a one-time milestone message at 7/30/100/365 days (4/12/26/52 weeks in weekly mode).
  Unit-tested; the banner has widget tests. Not yet looked at on the emulator.
- **G7 built (Android):** opt-in reminder (Settings -> Streaks): an explanation dialog first, then the system permission
  (it was already requested at app start for the playback notification, so no new prompt or manifest permission);
  time picker (default 7 pm), quiet hours (10 pm-8 am), "Send a test reminder". A small Kotlin channel sets one
  inexact alarm (`setAndAllowWhileIdle`, so no exact-alarm permission); `ReminderReceiver` posts the notification.
  Rules (unit-tested): off by default, none once the day is done, none without a streak, none in quiet hours, stops
  after 3 ignored in a row. Verified on the emulator: the test reminder appeared with the flame icon and text.
  **Limits:** alarms do not survive a reboot (rescheduled on the next app start; adding RECEIVE_BOOT_COMPLETED
  would be another permission); the time is fixed, not derived from the user's habits; iOS is not built (needs the Mac,
  a Swift channel on `UNUserNotificationCenter`).
- **H9 done:** reading positions that fail to upload are kept in a per-profile queue and retried by the sync controller
  (app start, reconnect, every 3 min); a queued position older than what the server holds is dropped, not pushed over
  it. Unit-tested (store); the flush itself is not exercised on a device.
- **J2 done:** Listen action in the PDF and comic readers (PDF and comics map by overall fraction and open at the mapped
  page), and a Read action in Now Playing for a linked audiobook (uses the live playback position). Not yet looked
  at on the emulator.
- **H8 partly done:** in-book search (bottom sheet, tap a passage to jump) and a time-left estimate in the EPUB footer
  (about 250 words a minute, from the text length) are built and verified on the emulator. No in-app dictionary: it would send
  words to a third-party service (a store disclosure) and Android's selection menu already has system Define/Translate
  where installed. **K9 done:** `CHANGELOG.md` and `RELEASING.md`.
- **Also:** "Play all" on collections and playlists skips ebook-only books (button disabled when nothing is playable);
  descriptions render as plain text (no raw `<br />`); a published year of 0 is hidden.

### Real-phone testing on the Pixel 8 Pro (2026-11-12), reader problems found and fixed

Tested with a separate debug build (`com.codeneedscoffee.steeped.debug`, "Steeped Dev"; a profile build has its own id
too), so the installed app was never replaced. Linking, Read at the matching spot and the new Home header all worked.
The user then reported four reader problems, all on Alchemised:

- **Laggy, highlight not working, odd paging: one root cause.** The book wraps each chapter in `<section>`, and
  `epub_view` makes one item per direct child of `<body>` (looking only inside `<div>`), so each chapter became one
  huge item: 90 items for the whole book instead of about 13,000 paragraphs. That item was built in one go (build
  frames of 300-850 ms), could not be selected from, and made page steps coarse. `unwrapContainerTags` removes
  section/article/main/aside wrappers; after it the reader shows normal paragraphs with the book's own indents,
  and the slow frames are only the one-off ones at load. A real-file check and two unit tests cover it.
- **Highlight:** long press now starts a selection with handles and the toolbar (verified on the phone). "Highlight" was
  last in the toolbar and hidden behind the overflow arrow behind the phone's many system items (ChatGPT, Vivaldi, Reddit,
  Translate...); it is now first. A real finger selection and the saved highlight were not exercised (adb cannot select a
  word); needs a manual check.
- **Cut-off bottom line and top gap:** a page step was 92% of the whole screen, ignoring the bars that cover the top and
  bottom, and the last visible line was cut mid-glyph. Page turns now step by the visible height minus 1.5 lines, the last
  line fades out, and the blank band above the text when the bars are hidden is only as tall as the camera cut-out.
  Not yet judged by the user on the phone.
- **Back after switching ebook -> audio -> ebook:** switches now replace the screen instead of stacking, so Back goes to the
  book page. Not yet exercised on the phone.
- **Measuring:** debug/profile builds log slow frames (build vs raster) as `[frame]` lines: the lag was all UI-thread build
  time, never the GPU; the phone's CPU was mostly idle. Page turns after the fix were 0-1 slow frames.
- A first fix for the crash "Cannot get size during build" (measuring the bottom bar while building) was caught
  on the phone and fixed; a test now covers the page-step geometry.

### Quick switch no longer freezes (2026-11-12), verified on the emulator

- **Cause:** a switch did all its work before changing screens: for Read it downloaded and parsed the whole EPUB to
  find chapter spans, for Listen it fetched the reading position, parsed the EPUB again and loaded the audio, and both
  could re-fetch item details (auto-disposing providers). The old screen just sat there.
- **Fix:** the screen changes at once and the slow parts run behind the destination's own spinner. Read: the reader
  maps the audio position itself after it has opened the book (one parse, shared with the reader). Listen: the open
  reader hands over its position and chapters (no network, no second parse), Now Playing opens first with its spinner,
  and the audio loads behind it; if it fails to load the screen pops back. The buttons load the linked item's details
  in the background so tapping needs no wait.
- **Measured (emulator, debug build):** Read -> reader with spinner in 0.74 s, Listen -> spinner in 0.74 s, Now Playing's
  Read -> reader in 0.41 s. Landing spots: reader 65% for audio 65%; audio at 34:55 of 53:42 (65%). One Back press
  after Read -> Listen -> Read returns to the book page. Not yet re-checked on the Pixel (the user needed it).
- Also done in this round: top/bottom margin slider, smaller top gap, Justify under Bold. Still open: tap-to-turn on the
  Pixel (works on the emulator; the user has not said where they tap).

### Highlight/bookmark fixes and Phase M (read and listen together), built 2026-11-13, not yet run on a device

- **Reader fixes:** a word highlighted twice is kept once (`mergeHighlights`); bookmarks can be renamed (reader: pencil in the Bookmarks tab; audio: new `PATCH /api/me/item/:id/bookmark`, assumed from the server API and unchecked); jumping to a highlight or bookmark now measures where the line landed and corrects it (`_revealIn`), and a bookmark jumps by its saved fraction instead of the CFI. The "a page too far" cause was not reproduced, so this needs the Pixel to confirm.
- **M0:** Listen (reader, EPUB only) and Read (Now Playing) open a drop-down: switch, or listen while reading / read along. Setting "When switching" (ask / switch / both); long-press always asks; already playing -> "Show player".
- **M1:** `ReaderPlayerDock` in the reader's bottom bar for the linked audiobook only (play/pause, skips, chapter time left, Follow, expand sheet with speed, sleep timer, chapter skip). Counted as covered area for page turns.
- **M2:** Follow: audio position -> paragraph (`followPosition`), accent band on that paragraph, scrolls only when it leaves the comfort zone, detaches on page turn / scrub / jump / finger drag. Settings: strip on/off, follow on/off.
- **M3:** long-press "Play from here" in the text selection menu.
- **M4:** Now Playing "Read along" text window (`bookTextProvider`, same paragraph split as the reader), tap opens the reader at that spot.
- **M7:** reading beside playing audio no longer adds streak minutes (`ReadingTracker` skips while audio plays).
- **M5:** at 720 dp wide or more (landscape phone, tablet) the strip becomes a 320 dp player column beside the page: cover, title, chapter, progress, play/skips, Follow switch, chapter skip, speed, sleep timer.
- **Tests:** 360 pass (new: read_along, switch_menu, merge_highlights, reading_overlap). **Not done / needs a device:** the real layout of the strip, Follow scrolling feel, "a page too far" confirmation, Play from here accuracy, the M5 layout on a real landscape screen, M6 Precise.

### Precise sync (J5/J6) built and verified on the Pixel, 2026-11-13

- **Spike:** the on-device recogniser transcribes decoded clips from a file (no microphone), about 20x faster than playback; needs the `RECORD_AUDIO` permission (now in the manifest) and the speech pack. Findings in PLAN.md (J5).
- **Audio -> ebook** (Read from the Alchemised page, Precise on): the reader opened on the exact paragraph the narrator was reading ("Paladia's a critical source of lumithium..."), checked on screen; the percentage estimate was about 300 paragraphs out, so the search widens.
- **Ebook -> audio** (Listen in the reader): guided search, 4 listens in about 21 s, landed on the audio position the book was at (30:34 + ~6 s). A plain scan took 52 s and missed because the estimate was 6 minutes out.
- **UI:** a centred frosted-glass "Finding your place..." card with a step counter ("check 3 of 4") on both the reader and Now Playing.
- **Touched real data:** the Alchemised audio position was moved by the tests; I put it back to 30:34 by hand. Its ebook position moved too (now near chapter 66).
- **Tests:** 373 pass (matcher incl. a real misheard transcript, guided search, fallbacks).

### Precise on a second book: Clockwork Angel (Cassandra Clare), 2026-11-13, on the Pixel

- **Finished book at the end:** reader opened on the acknowledgements at 100%; Precise found nothing there (silence) and kept the estimate - correct fallback.
- **The percentage estimate can be very far out:** at 40% of the ebook the chapter-weight estimate was 17,817 s while the true place was about 20,900 s (50 minutes out). A fixed window scan around it could never find it.
- **Fix:** ebook -> audio is now iterative: listen (25 s) at the guess, find the narrator's paragraph anywhere in the book, convert the word distance to seconds (speed measured from the last two listens), jump, repeat until within about 20 s. Round trip on the Pixel: reader at paragraph 1362 -> audio 20,915 s, score 0.96, 3 listens, about 15 s; the opposite direction from the audio time landed on paragraph 1363.
- **Data touched:** the test un-finished the book (progress 40%); I marked it finished again from Now Playing. Ebook position left near chapter 8; audio position left at 5:49:19 (it was at the end before).
- **Open:** why chapter-weight estimates drift this far for this book (chapter titles are "Chapter N", so title matching does nothing) - the overall-fraction fallback was closer (39.6% vs 33.9%); worth using as the first guess when titles are generic.

### Precise v2: faster and sharper (steps 1-4 of the research plan), 2026-11-13, on the Pixel

- **1. Better first guess:** ebook places are now counted in words, not paragraphs or HTML size (`ParagraphMap`: chapters from the contents list, word fraction both ways). The reader, Follow, Play-from-here and the Now Playing read-along all use it. On Alchemised the first guess is within about 40 paragraphs (0.3%) with no listening.
- **2. Calibration anchors:** every confirmed match (Precise either direction, Play from here) is saved as (word fraction, audio time) per book in the key-value table (`sync_anchors.dart`, max 40). Later guesses interpolate between anchors, or lean on a lone one within 10% of the book. Clockwork Angel: second switch's first guess was within 2 s.
- **3. Streaming listen with early stop:** the audio is decoded straight into the recogniser through a pipe and the words heard so far are sent to Dart, which judges them at about 5, 10, 18 and 26 s and cancels at the first confident match. Warm listens on the Pixel: 0.9-3 s (was about 7 s); a cold first listen after the app starts can still take about 10 s (network and recogniser start-up).
- **4. Matching upgrades:** rare words weigh more (book-wide frequency), a run of words in order is required (4 for a 5 s clip, 3 for 10 s, 2 for the full clip), and a margin over the runner-up (repeated passages are not trusted early). `BookIndex` is built once per switch.
- **Results:** Clockwork Angel audio -> ebook: 1 listen, 1.7 s, 5.2 s of audio; ebook -> audio: 0.9 s. Alchemised (no anchors) audio -> ebook: 3.2 s; ebook -> audio from a spot 5% away: 2 listens, about 3 s total, score 0.91.
- **Settings:** "Ebook to audiobook" and "Audiobook to ebook" are separate dropdowns (Off / Estimated / Precise each), so Precise one way and chapter sync the other works. A settings file from before the split carries its single value into both.
- **Left as it was:** Alchemised audio put back at 30:34:19; Clockwork Angel marked finished again (its page shows 40% until refreshed).
- **Tests:** 389 pass.

## To do

- G6: spike `POST /api/session/local` for reading sessions (decide device-only vs server).
- G7 on iOS (needs the Mac), reschedule-after-reboot decision, habit-based reminder time.
- L1-L7: update the website's policies and pages (L7; the Steeped-Site repo, `src/worker/pages/privacy.ts`; publish before submitting, the policy URL goes in both consoles), the Google Play Console (Data safety, foreground service, battery-optimisation and notification/microphone declarations) and App Store Connect (App Privacy, background audio, notifications), the store text and screenshots, and the privacy policy for the new permissions and data uses. Needs the user (console access); I prepare the inventory and wording. See PLAN.md Phase L.
- J2: Read switch in Now Playing, and Listen in the PDF/comic readers (item page and EPUB reader done).
- J4: confirm on the real Pixel that a Listen switch starts at the mapped time and that both progress rows update.
- J5/J6: Precise mode spike and build. Environment check 2026-11-12: the emulator (API 35, Google APIs image) has `RecognitionService`s (Google app voice search, `AiAiSpeechRecognitionService`), so the spike can start there, but it needs a Kotlin clip decoder (`MediaExtractor`/`MediaCodec`), `SpeechRecognizer.createOnDeviceSpeechRecognizer` with a file-descriptor audio source, an on-device language pack, and the `RECORD_AUDIO` question answered; whether it works depends on the Pixel's speech services, so plan to finish it on the Pixel. Not started.
- J7: emulator check of Listen direction and of a real ASIN/ISBN pair.
Maintained by the PLAN.md automated run: anything not built, not tested on the emulator, or needing the real Pixel is
logged here with the reason. Seeded 2026-11-10:

- **Emulator works** (`tool/emulator.sh`, AVD `steeped_test`, `-gpu host`); stop it during `flutter build` to avoid the OOM killer.
- **Still open from the original list:** H8-H10 (dictionary/search/time-left, offline position queue, true EPUB
  pagination), K4-K7/K9, and the Phase A-F re-checks on the emulator. Phase I is built and verified.
- **Known risk, now mitigated (J0):** a reader's `isFinished` on a combined audio+ebook item could mark the audiobook
  finished; readers no longer send it for items with audio.

- **Chromecast (Android) skipped** by decision 2026-11-10: needs a Cast SDK package, which conflicts with the
  first-party-only dependency rule. Revisit if that rule is relaxed (PLAN.md K3).

- **E-book progress isn't syncing** (reported 2026-11-02). `epub_reader_screen.dart:171`,
  `comic_reader_screen.dart:110` and `pdf_reader_screen.dart:75` call
  `ProgressRepository.updateEbookProgress` (PATCH `/api/me/progress/:id` with `ebookLocation` +
  `ebookProgress`), but there's no retry/durable queue like audio progress has (the pending-sync table has no
  ebook fields), errors may be swallowed, and the position may not be reloaded when the book is reopened.
  To investigate: log the PATCH result on a real EPUB, check the callback actually fires on page turns and on
  leaving the reader, confirm the server stores `ebookLocation`/`ebookProgress`, and make sure Home's
  "Continue reading" refreshes afterwards.

## Later

- Milestone 3 → 4 → 5, in that order. The next big native-divergence point is iOS **background URLSession**
  download behavior (Phase 6) — budget Mac/Xcode time there once the iOS side starts. CarPlay entitlement
  (0.13) status should also be checked as Milestone 4 approaches.

---

*Last updated: 2026-10-01 (auth refresh-failure handling + stuck-mini-player fixes — see the two bug-fix
entries above; note several commits between 2026-08-26 and this update — refresh-token fixes, playback
fixes, font sizing, playback speed, iOS deployment tweaks — landed without a matching ROADMAP entry and
aren't reconstructed here)*
