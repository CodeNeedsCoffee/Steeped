# Quality-of-Life Plan (branch `qol-features`)

Everything that isn't blocked by admin permissions or Mac/Apple access. Written 2026-10-07.
Blocked and out of scope here: add podcast, podcast auto-download, RSS feeds, primary/supplementary ebooks,
send-to-Kindle (all admin-gated), CarPlay and the iOS release checkpoints (need the Mac).
Also not included: volume-key navigation, lock player, MP3 index seeking (see PLAN.md 5.11/5.13).
Deferred by decision: podcast episodes in playlists and new-episode markers (old D6), shake-to-restart (old B5).

## Ground rules

- Work on branch `qol-features`. One phase at a time; nothing is committed or pushed until asked.
- **Testing happens in the Linux app** (`xvfb-run -a flutter test integration_test/<file> -d linux`,
  against audiobooks.dev demo/demo) plus unit/widget tests (`flutter test`). Linux has no audio, so
  audio-dependent behaviour (auto-rewind, fade-out, chime, queue) is covered by unit tests with a fake
  audio handler, then smoke-tested by hand on the Pixel. Anything not exercised is listed as unverified.
- Settings changes must stay backward compatible: every new `AppSettings` field gets a default in
  `fromJson`, so existing installs keep working untouched.
- **Every user-preference behaviour gets a control in Settings** (see the matrix below), with a default that
  keeps today's behaviour unless stated otherwise.
- **Dependency policy:** only first-party Google/Dart/Flutter packages, and nothing that forces changes to the iOS
  or Google Play submissions (no new permissions, entitlements, privacy-manifest entries or Info.plist usage
  strings). No new dependencies are currently planned: `intl`/`flutter_localizations`, `just_audio`,
  `connectivity_plus` and `drift` are already in the project. Native Android code inside the app (Kotlin, like the
  existing storage channel) is fine since it adds no package or permission.
- Each phase ends with `flutter analyze --no-fatal-infos` clean, all tests green, and PLAN.md/ROADMAP.md updated.

## Phase A: Settings foundation (small items, do first)

| # | Item | Where | Approach | Size |
|---|------|-------|----------|------|
| A1 | Separate jump-back / jump-forward lengths | `app_settings.dart`, `settings_screen.dart`, `playback_controller.dart` (`jumpForward/jumpBackward`), `steeped_audio_handler.dart` (`fastForward/rewind`) | Add `jumpBackSeconds`, `jumpForwardSeconds`; `fromJson` falls back to the old `jumpIntervalSeconds` so nobody's setting resets. Two sliders in Settings. Update the handler's lock-screen actions. | S |
| A2 | Cellular: Ask / Always / Never | `app_settings.dart`, `playback_controller._blockedByCellularSetting`, `download_controller._blockedByCellularSetting` | Replace the two bools with a `CellularPolicy` enum (migrate true->always, false->never). "Ask" shows a confirm dialog once per session per action and remembers the choice for the session. | M |
| A3 | Mask server address | `account_screen.dart`, `login_screen.dart`, `connect_server_screen.dart` | Setting `maskServerAddress`; render `https://••••` in the Account screen and login header; tap to reveal. | S |
| A4 | Hide Download without permission | `item_detail_screen.dart`, quick-actions sheet, download rows | Gate on existing `AuthUser.canDownload` (currently unused). | S |
| A5 | Allow seeking on lock-screen controls | `steeped_audio_handler.dart` (system actions), settings | Toggle `allowSeekOnMediaControls`; include `MediaAction.seek` only when on. | S |

Tests: unit tests for `AppSettings` migration (old JSON -> new fields), cellular policy decision function,
jump math with asymmetric values. Phone: confirm lock-screen skip buttons use the new lengths.

## Phase B: Playback behaviour

| # | Item | Approach | Size |
|---|------|----------|------|
| B1 | Auto-rewind on resume | Settings: Off (default) / 3 / 5 / 10 / 15 / 30 s. In `PlaybackController.resume()` seek back by the chosen amount, capped at the book start; optional "scale up after long pauses" switch (default off). Skip when resuming right after a load. | M |
| B2 | Sleep timer: end of chapter | New `SleepTimerMode` (duration or end-of-chapter). Chapter end comes from `item.chapters` and the position stream; pause when the position crosses it. | M |
| B3 | Sleep timer: fade-out | Ramp player volume down over the last N seconds (setting `sleepFadeOut`, default on) then restore volume on the next play. | M |
| B4 | Sleep timer: "30 seconds left" chime | Short bundled asset played on a second `AudioPlayer` just before the pause; setting to disable. | M |
| B5 | Sleep timer: quick extend | Replaces shake-to-restart (dropped: no first-party sensor package). An "+5 min" / "restart" button on the countdown chip and on the fired state; extend length is a setting. | S |
| B6 | Auto sleep timer window | Setting with start and end time; when playback starts inside the window, start the default-length timer automatically. | M |

Tests: unit tests with a fake handler for resume math (B1), end-of-chapter detection (B2), fade volume curve (B3), extend/restart (B5),
window logic including windows that cross midnight (B6). Phone smoke test for audio behaviour.

## Phase C: Progress

| # | Item | Approach | Size |
|---|------|----------|------|
| C1 | Discard progress | Overflow action on Now Playing and the item page: confirm, then `DELETE /api/me/progress/:id` (confirm the route in server `MeController`), clear the local cache row. | S |
| C2 | Sync-failed indicator | Expose the count from the pending-sync table as a provider; show a small badge on the mini-player/Now Playing and in Settings > Advanced, with "Retry now". | M |

Tests: integration test on the demo server (write progress, discard, confirm the server returns none);
unit test for the pending-count provider.

## Phase D: Library polish

| # | Item | Approach | Size |
|---|------|----------|------|
| D1 | Remember Books/Authors/Collections/Playlists choice | Store `section` in the same per-library `LibraryQuery` JSON. | S |
| D2 | "Has ebook" filter | Add an `ebooks` filter group; confirm the accepted values in server `libraryItemsBookFilters.js` first. | S |
| D3 | Go to author / series in quick actions; quick actions on shelves and item page | Parse author ids (and series id) from the minified item JSON into `LibraryItem`; reuse `showItemQuickActions` from `home_shell_screen.dart` shelf cards and the item detail screen. | M |
| D4 | Author page in reading order | The author detail response groups books under series with `sequence`; sort by series then sequence, standalone books after. | S |
| D5 | Collapse series | Add the server's `collapseseries` option and a toggle in the library toolbar; tapping a collapsed series opens the series page. | M |

Tests: extend `integration_test/library_features_test.dart` (section persists across a rebuild, ebook filter,
author page order, collapse toggle); unit tests for the sort helper and model parsing.

## Phase E: Account

| # | Item | Approach | Size |
|---|------|----------|------|
| E1 | Metered label + setting | Small Android channel in `MainActivity.kt` returning `ConnectivityManager.isActiveNetworkMetered`; Dart service combines it with `connectivity_plus`. Badge shows "Live (metered)". Setting **"Treat metered Wi-Fi like cellular"** (default off) makes the cellular policy (A2) apply to metered Wi-Fi such as a hotspot. iOS: label hidden, setting hidden. No new permission (`ACCESS_NETWORK_STATE` is already granted via `connectivity_plus`). | M |
| E2 | Multi-server / multi-account (see sub-plan) | Detailed below. | XL |

### E2 sub-plan: multiple servers and accounts

Read first: `session_storage.dart`, `session_controller.dart`, `socket_service.dart`, `dio_client.dart`,
`app_database.dart` (tables that hold server-specific data), `token_refresh_coordinator.dart`.

1. **Data model.** New `ServerProfile` (id, serverUrl, username, userId, displayName, lastUsedAt) stored in a drift
   table `ServerProfiles`. Tokens live in secure storage under `profile:<id>:*`; a small "active profile id" key
   decides which one boots. The current single session is migrated into profile #1 on first launch of the new
   version (drift `schemaVersion` bump with a tested migration; no logout, no data loss).
2. **Server-specific data gets a profile id:** `DownloadedItems`/`DownloadedTracks` (+ cover paths), pending
   progress syncs, cached library list, per-library query/sort/filter store, recent searches. Local-media imports
   are device-wide and stay profile-less. App settings, skin, logs stay global.
3. **Switching.** `SessionController.switchTo(profileId)`: stop playback, disconnect the socket, clear in-memory
   providers (libraries, items, shelves, playback item, queue), set the active profile, re-bootstrap with that
   profile's tokens, and rebuild the router state. Last-used profile boots on launch.
4. **UI.** Account screen lists profiles with Switch / Remove, plus **Add server or account** reusing the
   existing connect-server and login screens. A compact switcher (name + server host) in the Home app bar menu.
   Removing a profile asks whether to also delete its downloads (default: keep until confirmed).
5. **Offline behaviour (decided).** Downloads stay tied to the profile they came from. Offline, the Downloads
   screen shows every downloaded book, grouped by server; online it shows the active server's plus a section for
   others. Playing a download from another profile works offline; progress for it queues against its own profile and
   syncs when that profile next becomes active.
6. **Safety.** Refresh-token handling is per profile (no cross-profile token reuse); logout removes only the
   active profile's tokens; a forced logout on one profile never touches another.
7. **Settings control.** "Ask before switching while playing" (default on), "Show downloads from other servers"
   (default on).

Tests: drift migration unit test (old schema -> new, rows reassigned to profile #1); storage tests for per-profile
tokens; switching state-machine tests with fakes; Linux integration test that logs in to audiobooks.dev, adds the
local Audiobookshelf checkout (`~/Code/audiobookshelf`, `node index.js`) as a second server with its own user,
switches back and forth, and confirms library, search history and downloads stay separated. Phone smoke test at the end.
Because it changes storage and session code, E2 gets its own sub-branch off `qol-features` and lands last.

## Phase F: Polish

| # | Item | Approach | Size |
|---|------|----------|------|
| F1 | Light and black variants per skin | `Skin.buildTheme(Brightness/Variant)`; Appearance screen gets a Light / Dark / Black / Follow-system selector (persisted, default = today's dark look); audit hard-coded colors that ignore the theme (e.g. the mini-player glass fill). | L |
| F2 | Accessibility pass | Contrast-ratio unit tests per skin/variant, `Semantics` labels on icon-only buttons, 1.3x and 2x font-scale golden/overflow checks. | M |
| F3 | Native splash screen | Android 12 splash theme with the logo (no extra dependency), iOS launch storyboard image; avoid `flutter_native_splash` because of the earlier `image` package conflict. | S |
| F4 | Translation setup (English only) | Extract every hard-coded UI string into `app_en.arb` using `AppLocalizations`, move plurals/dates to `intl`, keep **only en-US** shipped. Add a lint-style test that fails if new user-facing string literals appear outside the ARB, and a short doc for adding a language (drop in `app_xx.arb`, add to `supportedLocales`). Language picker keeps showing English only until a second ARB exists. | L |
| F5 | Android Auto settings + Assistant voice | Settings for browse grouping limit and series order; implement `onPlayFromSearch` so "play <book>" works. Visual DHU pass still needs a manual run. | M |

## Suggested order

A (A1, A4, A3, A5, A2) -> B1 -> B2/B3/B4 -> C1/C2 -> B6/B5 -> D1/D2/D4/D3/D5 -> F3 -> F1/F2 -> E1 -> F5 -> F4 -> E2.
Small, high-visibility items first; the two large items (E2 multi-server, F4 translations) last.

## Settings matrix (every preference gets a control)

| Setting | Section | Default |
|---|---|---|
| Jump back / jump forward seconds (A1) | Playback | 30 / 30 (migrated from today's value) |
| Cellular streaming / downloads: Ask, Always, Never (A2) | Data | Always (today's behaviour) |
| Treat metered Wi-Fi like cellular (E1) | Data | Off |
| Show network type on the Live badge (E1) | User Interface | On |
| Mask server address (A3) | Account | Off |
| Allow seeking on lock-screen controls (A5) | Playback | On |
| Auto-rewind amount; scale after long pauses (B1) | Playback | Off; off |
| Sleep timer: end of chapter available, fade-out on/length, chime on/off, extend minutes, auto window on/start/end (B2-B6) | Sleep Timer | existing behaviour; fade on, chime on, auto window off |
| Show sync-failed indicator (C2) | Advanced | On |
| Remember library section / collapse series (D1, D5) | Library (new section) | On / Off |
| Theme: follow system / light / dark / black (F1) | Appearance | Dark |
| Ask before switching server while playing; show other servers' downloads (E2) | Account | On / On |
| Android Auto: browse grouping limit, series order (F5) | Android Auto (new section) | server defaults |

## Decisions (resolved 2026-10-07)

- Auto-rewind default: **Off**. Shake-to-restart: **dropped**, replaced by quick extend (B5).
- Metered: **label plus a setting** (E1). Multi-server: **built now**, downloads kept per server and shown together offline (E2).
- Translations: **setup only**, en-US stays the only language (F4). Podcast playlists: **deferred**.
- Dependencies: **first-party only**; none planned.

## Also resolved

- **E2 remove-profile:** ask each time whether to delete that server's downloads (default choice: keep).
- **F5 Assistant voice:** build the `onPlayFromSearch` hook; shipping without a real Google Assistant device test is accepted.

## Risks

- Audio features can't be heard on Linux, so they rely on unit tests plus a phone check.
- Changing cellular settings from bool to enum touches both streaming and downloads; migration must be tested.
- Multi-server touches session, socket, storage and every cache; it lands last on its own sub-branch, and the drift migration needs a tested rollback story (keep a backup copy of the database before migrating).
