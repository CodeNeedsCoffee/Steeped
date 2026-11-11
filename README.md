# Steeped: Modern Audiobooks

A Flutter client for a self-hosted [Audiobookshelf](https://www.audiobookshelf.org/) server — built for
Android and iOS, with a custom "glass/modern" design and swappable skins.

App Store listing name: **Steeped: Modern Audiobooks**. Referred to as just "Steeped" throughout the rest
of this doc, the codebase, and package identifiers — only the public-facing store listing uses the full name.

**Steeped is an independent, unofficial project.** It is not affiliated with, endorsed by, or maintained by
the Audiobookshelf team. It's a third-party client that talks to your own Audiobookshelf server over its
public API — full credit to that project for the server, the API, and the reference client this one aims
for feature parity with.

## Get Steeped

| Platform | Where | Status |
|---|---|---|
| iOS (stable) | [App Store](https://apps.apple.com/us/app/steeped-modern-audiobooks/id6797693643) | Live. Builds from `main` are submitted to App Review automatically. |
| iOS (preview) | [TestFlight public beta](https://testflight.apple.com/join/xESRcEcP) | Every push to the `preview` branch is built and sent to beta testers. |
| Android | Google Play | Work in progress, not publicly available yet. |

You need your own Audiobookshelf server to use the app.

## Why "Steeped"

Two meanings, on purpose:

- A lot of **coffee** went into building this (the project's original working name was
  *BooksNeedCoffee* — that spirit lives on here).
- The goal is for **readers and listeners to be steeped in a story** — fully soaked in it, the way tea or
  coffee steeps — rather than just passively consuming it.

## Platform Scope

**Android and iOS only.** The `macos/`, `linux/`, `windows/`, and `web/` folders that `flutter create`
scaffolds by default have been removed — desktop and web are not targets for this project.

## Tech Stack

Locked in during Phase 0 of the build plan — see the old build plan (`git show a9e7ad8:PLAN.md`) (0.1–0.13) for full rationale on each.

| Concern | Choice |
|---|---|
| State management | Riverpod |
| Navigation | go_router |
| Networking | dio |
| Real-time | socket_io_client (socket.io v4 — the server doesn't speak raw websockets) |
| Local database | drift (SQLite) |
| Secure storage | flutter_secure_storage |
| Audio | just_audio + audio_service |
| Downloads | background_downloader |
| E-books | epub_view/epubx (EPUB), pdfx/syncfusion_flutter_pdfviewer (PDF), archive (CBZ/CBR) |
| Casting (Android-only, later) | flutter_chrome_cast |
| Connectivity | connectivity_plus |
| Localization | flutter_localizations + intl |
| Car integration | audio_service (Android Auto), flutter_carplay (CarPlay) |

## Project Docs

- [`PLAN.md`](PLAN.md) — the single plan: phased work, how each item is built and tested on the
  virtual Android device, and the remaining roadmap.
- [`ROADMAP.md`](ROADMAP.md) — a lightweight, at-a-glance status tracker, updated as work lands.

## Getting Started

This is a standard Flutter project.

```
flutter pub get
flutter run
```

See `PLAN.md` for the plan; architecture and tech-stack decisions as they're made.
