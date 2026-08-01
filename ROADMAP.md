# Steeped — Roadmap

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
| 4         | Car integration — Android Auto & CarPlay          | 10            | ⚪     |
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

## Next

- Continue Milestone 3 Phase 2: 2.5 (shared component library), brightness variants, deeper accessibility
  audit — or move on to Phase 10 (car integration) if evan would rather revisit skin polish later once
  there's real feedback on the two skins built so far.
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

*Last updated: 2026-08-01 (Milestone 2 fully complete; Milestone 3 skin engine + library retrofit built and verified live)*
