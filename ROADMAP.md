# Steeped — Roadmap

A quick-glance status tracker. For the full detailed checklist (sub-tasks, feature-parity ledger, testing
cadence) see [`PLAN.md`](PLAN.md) — this file is just the "where are we" summary, meant to be hand-updated
as work lands.

Platforms: **Android + iOS only.**

Status legend: ⚪ Not started · 🟡 In progress · 🟢 Done

| Milestone | Focus                                             | Phases        | Status |
|-----------|----------------------------------------------------|---------------|--------|
| 1         | Core streaming — connect, authenticate, browse, stream, basic UI | 0, 1, 3, 4, 5 | 🟢 done |
| 2         | Content, offline & downloads — downloads/local media, podcasts, e-books, account/settings/stats | 6, 7, 8, 9 | 🟡 (6 done) |
| 3         | UI customization & skins                          | 2             | ⚪     |
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
  a durable offline-sync retry queue (6.7) deliberately deferred — see `PLAN.md` Phase 6 for why.
- **Bug fix (2026-07-31, reported by evan)**: a downloaded book wasn't resuming from its saved position.
  Root cause: the progress-sync timer only stopped via in-app pause, not hardware/notification pause (which
  calls the audio handler directly) — it kept ticking in the background and, once connectivity returned from
  the Phase 6 offline test above, synced a stale near-zero position to the real server, silently overwriting
  real progress. Fixed by tying the timer to actual playback state instead. **This did corrupt real progress
  on evan's server for one book during testing**; repaired using the still-intact progress percentage.
  Verified fixed: resumes correctly now. See `PLAN.md` Phase 5.9 for details.

## Next

- Phase 7: Podcasts (Milestone 2) — podcast library, episode list, subscribe by term/RSS, auto-download
  (reuses the Phase 6 download engine), episode delete.
- Worth considering first: the cold-start-while-offline gap found during Phase 6 verification (see above) —
  a Phase 3 follow-up, not scoped to any single phase yet.

## Later

- Milestone 2 → 3 → 4 → 5, in that order. The next big native-divergence point is iOS **background
  URLSession** download behavior (Phase 6) — budget Mac/Xcode time there once the iOS side starts.

---

*Last updated: 2026-07-31*
