# Steeped — Roadmap

A quick-glance status tracker. For the full detailed checklist (sub-tasks, feature-parity ledger, testing
cadence) see [`PLAN.md`](PLAN.md) — this file is just the "where are we" summary, meant to be hand-updated
as work lands.

Platforms: **Android + iOS only.**

Status legend: ⚪ Not started · 🟡 In progress · 🟢 Done

| Milestone | Focus                                             | Phases        | Status |
|-----------|----------------------------------------------------|---------------|--------|
| 1         | Core streaming — connect, authenticate, browse, stream, basic UI | 0, 1, 3, 4, 5 | 🟡 (0, 1 done) |
| 2         | Content, offline & downloads — downloads/local media, podcasts, e-books, account/settings/stats | 6, 7, 8, 9 | ⚪     |
| 3         | UI customization & skins                          | 2             | ⚪     |
| 4         | Car integration — Android Auto & CarPlay          | 10            | ⚪     |
| 5         | Stretch goals & release prep                      | 11, 12        | ⚪     |

## Now

- Project renamed to **Steeped** ✅
- Plan reorganized into the 5 milestones above ✅
- Phase 0 tech-stack decisions locked in ✅ — CarPlay entitlement requested from Apple, **awaiting approval**
  (0.13 — will nudge you again as Milestone 4 approaches)
- Phase 1 skeleton built ✅ and verified on-device ✅ — folder structure, packages, Riverpod, go_router
  placeholder routes, drift DB, i18n scaffolding, minimal theme baseline. Confirmed launching cleanly on a
  Pixel 8 Pro (Android 17) with no crashes.

## Next

- Phase 3: Server Connection & Authentication — connect-to-server screen, login, secure token storage,
  websocket connection status

## Later

- Milestone 1 → 2 → 3 → 4 → 5, in that order. The two big native-divergence points to budget Mac/Xcode
  time around are **Phase 5** (background audio, Milestone 1) and **Phase 6** (offline downloads/local
  media, Milestone 2).

---

*Last updated: 2026-07-31*
