# Steeped: Modern Audiobooks — Roadmap

A quick-glance status tracker. For the full detailed checklist (sub-tasks, feature-parity ledger, testing
cadence) see [`PLAN.md`](PLAN.md) — this file is just the "where are we" summary, meant to be hand-updated
as work lands.

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
- Still worth a look next time on-device: confirm a real PDF item exists somewhere in evan's library to
  close out Phase 8.3's verification gap; verify Phase 9's cellular controls against a real cellular-only
  connection (needs airplane mode + manually re-enabled mobile data).
- Whenever real app-icon artwork exists: revisit Phase 9.9, including whether `epub_view`'s `image` ^3.x
  pin still blocks `flutter_launcher_icons`/`flutter_native_splash`.

## Later

- Milestone 3 → 4 → 5, in that order. The next big native-divergence point is iOS **background URLSession**
  download behavior (Phase 6) — budget Mac/Xcode time there once the iOS side starts. CarPlay entitlement
  (0.13) status should also be checked as Milestone 4 approaches.

---

*Last updated: 2026-08-01 (Milestone 2 fully complete; Milestone 3 skin engine + Milestone 4 Android Auto foundation both started; socket auth bug fixed)*
