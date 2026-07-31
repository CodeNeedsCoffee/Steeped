# Steeped — Roadmap

A quick-glance status tracker. For the full detailed checklist (sub-tasks, feature-parity ledger, testing
cadence) see [`PLAN.md`](PLAN.md) — this file is just the "where are we" summary, meant to be hand-updated
as work lands.

Platforms: **Android + iOS only.**

Status legend: ⚪ Not started · 🟡 In progress · 🟢 Done

| Milestone | Focus                                             | Phases        | Status |
|-----------|----------------------------------------------------|---------------|--------|
| 1         | Core streaming — connect, authenticate, browse, stream, basic UI | 0, 1, 3, 4, 5 | 🟡 (0, 1, 3 done) |
| 2         | Content, offline & downloads — downloads/local media, podcasts, e-books, account/settings/stats | 6, 7, 8, 9 | ⚪     |
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

## Next

- Phase 4: Library Browsing — data models, home shelves, full library view (single default look; skins
  come in Milestone 3), authors/series/collections, filter/sort, search, item detail

## Later

- Milestone 1 → 2 → 3 → 4 → 5, in that order. The two big native-divergence points to budget Mac/Xcode
  time around are **Phase 5** (background audio, Milestone 1) and **Phase 6** (offline downloads/local
  media, Milestone 2).

---

*Last updated: 2026-07-31*
