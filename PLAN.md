# Steeped Plan (branch `qol-run`)

Everything that isn't blocked by admin permissions or Mac/Apple access. Written 2026-10-07.
Blocked and out of scope here: add podcast, podcast auto-download, RSS feeds, primary/supplementary ebooks,
send-to-Kindle (all admin-gated), CarPlay and the iOS release checkpoints (need the Mac).
Also not included: volume-key navigation, lock player, MP3 index seeking (see the Phase K notes).
Deferred by decision: podcast episodes in playlists and new-episode markers (old D6), shake-to-restart (old B5).

## Ground rules

- Work on branch `qol-features`. One phase at a time; nothing is committed or pushed until asked.
- **Automated run workflow (per item, in this order):**
  1. **Build** the feature (code + unit/widget tests, `flutter analyze --no-fatal-infos` clean).
  2. **Test on the virtual Android device:** `tool/emulator.sh` boots the `steeped_test` AVD (Android 35, headless,
     `-gpu host`; the software GPU modes segfault on this machine), then `flutter build apk --debug`,
     `adb install -r`, and drive the feature with `adb` / `flutter test integration_test/<file> -d <emulator id>`
     against audiobooks.dev (demo/demo). Stop it with `tool/emulator.sh stop`. The Linux desktop app
     (`xvfb-run -a flutter test integration_test/<file> -d linux`) is a fallback for UI-only checks.
  3. **Update `ROADMAP.md`** with the outcome as the item completes: what was built, how it was verified (unit /
     emulator / Linux), and anything left unverified. Do not mark something verified that was not exercised.
  4. **Anything not finished or not tested in the run** (skipped, failed, blocked, needs the real Pixel, needs a
     decision) is logged under "To do" in `ROADMAP.md` with the reason, so nothing disappears.
  Emulator limits: audio output is disabled (`-no-audio`), so audio behaviour is covered by unit tests with a fake
  audio handler and by checking session/progress traffic against the server; the AVD has no Play Store, so
  on-device speech packages must be checked before relying on them (the planned ebook<->audiobook link). Real-device-only checks go to the To do list.
- This file is the only plan. The old build plan (previous `PLAN.md`) and `SESSIONS_PLAN.md` were merged in on 2026-11-10 (the old
  one is recoverable with `git show a9e7ad8:PLAN.md`); `ROADMAP.md` is the running status log and To do list, not a plan.
- **Git workflow (decided 2026-11-10):** the run happens in a separate worktree on its own branch (`qol-run`, at
  `~/Code/Steeped-run`), created from the current branch with today's uncommitted work carried over as its first commit.
  I may commit there freely as I go (one commit per item or phase, no AI attribution trailers). **Nothing is ever
  pushed.** At review time the commits are discarded in favour of a clean branch: I rebuild the changes there and
  **stage** them in sensible groups, and **the user makes the commits**. Until then `qol-run` is scratch history.
- **Test data:** audiobooks.dev (demo/demo) has other libraries beyond the audiobook one, including ebook and comic
  libraries (example: `https://audiobooks.dev/audiobookshelf/library/f6a47b56-d672-43b3-8c0c-99236d816020`). Find items
  there for EPUB / PDF / CBZ checks. Never modify data on any server other than the demo one; nothing is uploaded
  to or deleted from the user's real server.
- Settings changes must stay backward compatible: every new `AppSettings` field gets a default in
  `fromJson`, so existing installs keep working untouched.
- **Every user-preference behaviour gets a control in Settings** (see the matrix below), with a default that
  keeps today's behaviour unless stated otherwise.
- **Dependency policy:** only first-party Google/Dart/Flutter packages, and nothing that forces changes to the iOS
  or Google Play submissions (no new permissions, entitlements, privacy-manifest entries or Info.plist usage
  strings). **Exception (decided 2026-11-10):** the opt-in Precise sync mode (Phase J) may use the `RECORD_AUDIO` permission, requested only when the user enables it. **Exception (decided 2026-11-12):** opt-in streak reminders (G7) may use local notifications (`POST_NOTIFICATIONS`, already declared for the playback notification, and the iOS notification authorization). Any permission or data-use change must be reflected in the store listings before release (Phase L). No new dependencies are currently planned: `intl`/`flutter_localizations`, `just_audio`,
  `connectivity_plus` and `drift` are already in the project. Native Android code inside the app (Kotlin, like the
  existing storage channel) is fine since it adds no package or permission.
- Each phase ends with `flutter analyze --no-fatal-infos` clean, all tests green, and ROADMAP.md updated.

## Phase V: Verification pass (do first)

Goal: before adding anything, test what is built but unconfirmed, and record the result in `ROADMAP.md`. Each check is
run on the emulator (see the workflow above) and is logged as verified, failed (with the fix) or "needs the real Pixel".

| # | Check | How | Records |
|---|-------|-----|---------|
| V1 | Emulator boots, debug APK installs and launches, login to audiobooks.dev works | `tool/emulator.sh`, `adb install -r`, screenshot | ROADMAP To do item closed |
| V2 | Stuck-header fix (H6): half-configured / older server shows the header, account menu and log out | Point the app at an empty library or an unreachable library call | ROADMAP |
| V3 | Ebook reader (H1-H5) per format: EPUB, PDF, CBZ open; paged vs scroll defaults (comics scroll, others paged); tap zones; scrubber; bookmarks; highlights; settings persist | Find format items in the demo server's ebook and comic libraries (see Test data); if a format has no item, log it as blocked | Per-format verified / blocked |
| V4 | Ebook progress sync (H2/H3): position PATCH reaches the server in the official format; reopening resumes at the newest of device and server; "Continue reading (N%)" | Read server state with `GET /api/me/progress/:id` before and after | Close the ROADMAP "E-book progress isn't syncing" item or keep it with findings |
| V5 | Existing app behaviour on a fresh install: downloads, playback progress, Stats, History | Smoke test; audio itself cannot be heard (no audio), so check progress/session traffic | ROADMAP |
| V6 | Unit suite and `flutter analyze` still pass on the current tree | `flutter test`, `flutter analyze --no-fatal-infos` | ROADMAP |

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

## Phase G: Streaks

Written 2026-11-09 after reviewing the current code, the server and the two other local apps.

### What exists today

- `ListeningStats.currentStreakDays` / `longestStreakInYear` (`lib/models/listening_stats.dart`) count consecutive days
  with listening in the server's `days` map. They show on the Stats and Year-in-review screens only; nothing on Home.
- **Depends on Phase I:** the app does not open listening sessions today, so even listening adds no new `days`.
- The server builds `days` purely from **playback sessions** (`ApiRouter.getUserListeningStatsHelpers`). Reading an
  ebook creates no session, so **reading never counts toward a streak**. With the new ereader that is the biggest gap.
- Day keys are in the *server's* timezone; `_anchorDay()` already compensates for a server that is "tomorrow" locally.
- AudioBooth (iOS) has a daily goal in minutes (`dailyGoalMinutes`), a "day streak" count on its Home stats card and
  Daily Goal / Listening Activity widgets. The official `audiobookshelf-app` has no streak at all.

### Research summary (what other apps do)

- **Kindle** keeps two streaks in Reading Insights: a daily one (reset on a missed day) and a weekly one (one reading
  day per week). It only counts Kindle reading, so a day of audiobook listening breaks it; users complain about that
  and about the counter lagging a few days.
- **StoryGraph** has a daily streak that can be switched to weekly; users report the weekly one is much less stressful.
- **Apple Books** counts consecutive days that reach a daily reading goal, default 5 minutes.
- **Streak design write-ups** (mostly vendor blogs, not rigorous studies, so treat the numbers loosely) agree on:
  streaks work through loss aversion, so they matter once there is something to lose (about day 7+); a hard reset to
  zero after a single miss drives people away; a freeze or grace day softens that; milestones at 7/30/100/365 days are
  the usual celebration points; and the rules should be transparent and not guilt-based.

**Takeaway for Steeped:** count listening *and* reading as one activity streak (Kindle's weak spot), make the bar a
choice (any activity or a minutes goal), forgive an occasional miss, and keep it quiet and optional.

### Items

| # | Item | Approach | Size |
|---|------|----------|------|
| G1 | **Built 2026-11-12** Reading counts as activity | Readers record active reading time per day on the device (foreground, reset after ~2 min idle, so an open book on a table counts for nothing). Stored in a small drift table `ReadingDays(profileId, date, seconds)`, keyed by the device's local date. | M |
| G2 | **Built 2026-11-12** One merged streak | A day is active when server listening seconds + local reading seconds reach the threshold. Pure function `computeStreak(days, readingDays, settings, now)` replacing the two getters; no stored streak state, so it can't drift or need repair. Keeps the existing server-timezone anchor. | M |
| G3 | **Built 2026-11-12** Daily goal / threshold | Setting: "Any activity" (default) or a goal of 5 / 10 / 15 / 30 / 60 min. Matches Apple Books' goal model and AudioBooth's `dailyGoalMinutes`. | S |
| G4 | **Built 2026-11-12** Forgiveness | Setting "Forgive a missed day" (default on): one missed day is bridged at most once per 7 days and never two in a row. Computed from history, so it is deterministic and explainable ("1 day saved"). Optional **Weekly** mode (one active day per week) like Kindle / StoryGraph. | M |
| G5 | **Built 2026-11-12** Surfaces | Flame + count chip in the Home app bar (tap opens Stats); a "today" ring or tick on it; a 7-day dot row and **longest streak (all time)** on Stats; a quiet in-app banner when the streak is at risk (today empty, active yesterday); a one-time toast at 7 / 30 / 100 / 365 days. | M |
| G6 | Cross-device reading (spike first) | `POST /api/session/local` (what the official app uses to sync offline sessions) could record a reading session so reading shows up in the server's stats and on other devices. **Unverified and risky:** it also writes media progress from the session (`duration` 0 for an ebook) and would add reading time to "listening" totals and admin stats. Test against the local server (`~/Code/audiobookshelf`, a throwaway item) before deciding; ship G1-G5 without it. | M (spike S) |
| G7 | **Built 2026-11-12 (Android; iOS needs the Mac)** Streak reminders | Local scheduled notification, off by default, opt-in with a short explanation before the system prompt. See "G7: Streak reminders" below. Depends on G5's at-risk function. | M |

### G7: Streak reminders (back in scope, decided 2026-11-12)

Originally parked on 2026-11-09 (G1-G5 in-app only). Notifications are back in the plan: build them after G5, local only, opt-in.

- **Permissions:** Android 13+ `POST_NOTIFICATIONS` is already declared (playback notification), so the manifest does not
  change; the runtime prompt for reminders must be explained first and only requested when the user turns reminders on.
  iOS needs the notification authorization request (no Info.plist usage string). Exact alarms are not needed: a reminder
  that fires within a few minutes of the chosen time is fine, so do not declare `SCHEDULE_EXACT_ALARM`. Record the
  change in the store listings (Phase L1-L3).
- **Design (build on what G5 already has):**
  - Keep the "at risk" test as one pure function (`streakAtRisk(days, readingDays, settings, now)`) that the in-app
    banner calls today and a notifier can call later.
  - Keep the user's usual activity time of day (derived from the local `ReadingDays` / session times) available from
    the stats code, so a reminder can be timed for a few hours before they normally read or listen.
  - Settings keys (add with the UI): `streakReminderEnabled` (false), `streakReminderTime` (null = auto from habit),
    `streakReminderQuietHours`.
- **Likely approach:** local scheduled notifications only (no server, no push service, no account data leaves the
  device). The first-party option is `flutter_local_notifications` (not Google-published, so check the dependency
  policy) or a small Kotlin/Swift channel like the existing storage channel, which fits the policy better.
  A reminder is rescheduled each time the app records activity, and cancelled once today's bar is met.
- **Rules to keep when it is built:** off by default; one reminder per day at most; never after the day is already
  complete; no guilt copy ("Keep your 12-day streak going" rather than "You'll lose..."); respect quiet hours; stop
  after several ignored reminders in a row; explain the permission prompt before showing the system one.
- **Not feasible without a server change:** reminders that fire when the app is closed and the phone is offline are
  fine locally, but a reminder based on activity from *another* device would need the app to have synced first.
- **Open questions for then:** which channel/importance on Android; whether to add a Settings "Send a test reminder"
  button; whether milestone celebrations (7/30/100/365) should also notify.

### Decisions to make

1. **Notifications.** Decided 2026-11-12: reminders are in scope as G7 (local, opt-in, off by default); the store listings are updated for them in Phase L.
2. **Weekly mode and goal default.** Default is daily + any activity + forgiveness on. Confirm.
3. **G6 spike.** Run it, or keep reading streaks device-only?

### Edge cases

- Reading days use the device's date while listening days use the server's. They are merged by date string, so around
  midnight in a different timezone a day can land on the neighbouring date. Acceptable; the anchor logic covers "today".
- Switching profiles (E2): reading days are per profile; a server-only stat stays per server.
- Reinstalling loses local reading days (listening days come back from the server). Include `ReadingDays` in the
  existing database backup.
- Hiding the feature: setting "Show streak" (default on) removes the Home chip and banners; Stats still shows history.

### Tests

Unit tests for `computeStreak` with a fake clock: threshold on and off, forgiveness (one gap, two gaps, two in a row),
weekly mode, server-timezone anchor, merged listening + reading, and a streak that is safe until end of today.
Widget test for the Home chip and the at-risk banner. Reader test that idle time is not counted.

## Phase H: Ebook reader

Written 2026-11-09/10. H1-H6 are built (uncommitted, unverified on a device: only unit tests and `flutter analyze`);
H7 onward is open. See the debug APK note in the project memory for how fixes reach the phone.

| # | Item | Status |
|---|------|--------|
| H1 | Paged / scroll reading mode per format (EPUB and PDF default to pages, comics to scroll), switchable from the reader and Settings | Built |
| H2 | Progress in the official apps' format (1-based page for PDF and comics; ebook progress shown on the item page) | Built |
| H3 | Resume: fresh server position vs. the device copy, newest wins; "Continue reading (42%)" button | Built |
| H4 | Kindle-style reading UI: tap the middle to hide or show the bars, tap the edges to turn pages, progress scrubber with chapter label, brightness, keep screen on, justify, margins | Built |
| H5 | Bookmarks and highlights (device-only: the server has no ebook support for either) | Built |
| H6 | Stuck screens on a half-configured server: header, account menu and log out on the empty / failed / loading Home states | Built |
| **H7** | **Hide the Play button on ebook-only items** (see below) | **Open** |
| H8 | Dictionary lookup, in-book text search, time-left estimate | **Search and time-left built 2026-11-12; dictionary not built** (an in-app lookup would send the word to a third-party service and need a store disclosure; Android's selection menu already offers the system's Define/Translate where installed) |
| H9 | Offline queue for reading-position syncs (a failed sync is only retried on the next change today) | **Built 2026-11-12** |
| H10 | True EPUB pagination (needs a custom renderer; `epub_view` can only scroll, so "pages" are screen-height jumps today) | Open, large |

### H7: hide Play where there is no audio

Today an ebook-only item (EPUB, PDF, comic with no audio files) still shows a greyed-out **Play** button.

- **Item page** (`item_detail_screen.dart`): the Play button is only *disabled* when `item.tracks.isEmpty`. Show it only
  when `item.tracks.isNotEmpty`. When it is hidden, make **Read / Continue reading** the filled primary button and the
  only action in that row. Items with both audio and an ebook keep both, Play first.
- **Quick-actions sheet** (`library_actions.dart`, `showItemQuickActions`): shows Play for every book, ebook-only
  included, where it can only fail. Replace it with **Read** for an ebook-only item (open the right reader by format).
  `LibraryItem` has `hasEbook` but no "has audio" flag, so parse one from the minified list JSON (`numAudioFiles` or
  `duration > 0`; confirm which field older servers send) and add `hasAudio` to the model.
- **Shelf rows** (`home_shell_screen.dart`): audio-only `playItem` call on tap; an ebook-only item in Continue Listening
  should open its reader instead. Check the other continue shelves (the server's "Continue Reading" shelf is ebook-only).
- **Downloads**, **Series** and **Collection** lists: same check wherever a row's tap starts playback.
- **Also hide audio-only affordances** on such items: the Download button (already gated on tracks), sleep-timer and
  speed entry points, and the audio "Mark finished" wording if it differs.
- **Tests:** widget test for the item page with (audio only, ebook only, both): Play visible, Read visible, primary
  button correct; unit test for the `hasAudio` parse with and without the field (older servers).

## Phase I: Listening sessions (prerequisite for streaks and History) - BUILT, verified 2026-11-11

**Status correction (2026-11-11):** this phase was already built in the committed code
(`listening_session_repository.dart`, `listening_session_tracker.dart` with `listening_session_tracker_test.dart`,
the `PendingListeningSessions` table and its upload in `pending_sync_controller.dart`); the text below was merged in
from a stale plan and described it as unbuilt. Verified this run: I0 (the endpoints behave as described) and I7
(about a minute of playback on the emulator produced a History row, today's bar, "Days listened 1" and a 1-day
streak). Not re-verified: I4 offline queue upload, and the midnight/timezone edge (the server's day key was
already "tomorrow" locally; the Stats chart handled it with the existing anchor). Treat I1-I7 as done unless a
check below fails; only I4's emulator check and I5's timezone rule remain open.


Merged from the former `SESSIONS_PLAN.md` on 2026-11-10. Written from knowledge of the Audiobookshelf API; **nothing
below is verified yet**, which is what step I0 is for. Do this before Phase G: the streak has nothing to count without it.

### Why sessions and streak don't update

The app only ever calls the sessionless `PATCH /api/me/progress/:id` (`progress_repository.dart`, called from
`PlaybackController`'s 15 s tick, on pause, and on finish). That updates *where you are in a book*. It does **not**
create an Audiobookshelf listening session, and the server derives everything else from sessions:

| Screen | Server data | Written by |
|---|---|---|
| History / Recent sessions | `/api/me/listening-sessions` | playback sessions |
| 7-day chart, best day, daily average, days listened | `listening-stats.days` | `timeListened` sent to `/api/session/:id/sync` and `/close` |
| By day of week | `listening-stats.dayOfWeek` | same |
| Year in review | sessions + `days` | same |
| Streak (`currentStreakDays`) | computed client-side from `days` | same |

No sessions means no new `days` entries, so the streak stops at the last day the official app (or an older build)
logged, and History never grows. The streak code itself is fine; it has nothing to count. Verified earlier against the
live account: 1228 sessions, 573 days, 6-day streak, all from other clients.

### What we need

A real session lifecycle alongside the existing progress PATCH.

1. **Open** when playback starts: `POST /api/items/:id/play` (podcast episode: `/api/items/:id/play/:episodeId`) with
   `{deviceInfo:{clientName:'Steeped',...}, forceDirectPlay:true, forceTranscode:false, supportedMimeTypes:[...]}`.
   Keep the returned session `id`. We keep using our own URLs for audio (direct play), so ignore the returned tracks.
2. **Sync** every 15 s tick and on pause: `POST /api/session/:id/sync` with `{timeListened, currentTime, duration}`.
   `timeListened` is wall-clock seconds actually played since the previous sync (not position delta; seeking must not
   count, and 2x speed counts real time).
3. **Close** on stop, item switch, finish and app teardown: `POST /api/session/:id/close` with the same body. Close the
   old session before opening the next.
4. **Keep the PATCH progress call** as the source of truth for position and the offline queue; the session call is
   additive. If the session calls fail they must never block or delay playback (same 10 s cancel deadline as progress).
5. **Offline / downloaded listening:** accumulate `timeListened` locally and upload later with
   `POST /api/session/local` (one session) or `/api/session/local-all` (batch), as the official app does. Needs a new
   drift table next to `PendingProgressSyncs`, per profile (E2), drained by `pending_sync_controller.dart`.
6. **Streak correctness (client):** `days` keys are in the *server's* timezone, while `currentStreakDays` and the 7-day
   chart use the device's local date. Pick one rule (use the device date and send `timeListened` so the server buckets
   it, accepting an edge mismatch near midnight) or read the server's `today` field. Show the streak from freshly
   fetched stats after a session closes (invalidate `listeningStatsProvider` and the history provider on close, and on
   returning to Stats/History). This overlaps G2's anchor logic; decide once.
7. **Stats refresh:** `listeningStatsProvider` is `autoDispose`, so it refetches on open; the History controller loads
   once in `build()`. Add pull-to-refresh and reload on screen focus.

### Items

| # | Item | Approach | Size |
|---|------|----------|------|
| I0 | Verify the endpoints | Against audiobooks.dev (`demo`/`demo`) with a throwaway session: open, sync 30 s, close; then read `listening-stats`, confirm `days[today]` rose and the session shows in `listening-sessions`. Also confirm what `/play` returns for a direct-play item and whether `forceDirectPlay` avoids a transcode. | S |
| I1 | `SessionRepository` | `data/session_repository.dart`: `open`, `sync`, `close`, using the same deadline helper as `ProgressRepository`. | S |
| I2 | Played-seconds accounting | `PlaybackController` holds `_sessionId` and `_lastSessionTick`; a stopwatch driven by the existing `playing` stream (pause and buffering stop it; speed scales nothing). | M |
| I3 | Wire the lifecycle | Open/sync/close in `playItem`, the sync tick, pause, finish and item switch. | M |
| I4 | Offline queue | New drift table + migration (schema bump; the pre-migration backup already exists), drain on reconnect, `local-all` upload. | M |
| I5 | Streak/date handling and refresh | Items 6 and 7 above. | S |
| I6 | Tests | Fake `SessionRepository`; played-seconds accounting (pause, seek, speed, rapid item switch); close-on-switch; failure never blocks playback; streak across local midnight and month boundaries. | M |
| I7 | Live device check | Listen 2 minutes; confirm a new History row and that today's bar and the streak update. | S |

### Risks / open questions

- **Double counting:** if `/play` or the session sync also moves progress it could fight the PATCH. Verify in I0; if so,
  drop the PATCH while online.
- `/play` on a very large library or a transcode-capable server may do extra work; direct-play flags should keep it cheap.
- **Podcasts and ebooks:** podcast episodes use the episode path; ebooks must not open listening sessions (reading time
  is handled by G1/G6 instead).
- Linux desktop playback can't test any of this until the mpv backend works; use the Android build or the emulator.

## Phase J: Link an ebook and an audiobook (switch and sync)

Goal: from a book's page, jump between its ebook and audiobook and land at the matching spot, with progress kept in
step. Written 2026-11-10 from the server and the two other local apps; the matching behaviour is unverified.

### What the server gives us

- **Same item (one library item with both audio and an ebook file):** one `MediaProgress` row per (user, item) holds
  `currentTime`, `ebookLocation`, `ebookProgress` and a single `isFinished`. No linking needed, but the shared
  `isFinished` is a bug risk (below). Minified item JSON has `numAudioFiles` and `ebookFormat`.
- **Two separate items (an audiobook item and an ebook item):** the server has **no link between them**. They can be
  matched by `asin` / `isbn`, else normalised title + author (+ series and sequence). Progress rows are independent.
- The server has audio chapters with titles and times; EPUBs have a table of contents. Neither gives a per-sentence
  timestamp, so an exact position needs alignment (Precise mode) or is an estimate.

### Link model

A small drift table `ItemLinks(profileId, audioItemId, ebookItemId, source)` where `source` is `same-item`, `auto` or
`manual`. Links live on the device (the server cannot store them). Auto-suggest candidates by ASIN, then ISBN, then author +
book title; the user confirms before a link is saved. Manual link and unlink from the item page.

### Sync mode (a Setting, default Estimated)

`SyncStrategy` interface: given a position in one format, return the matching position in the other plus a confidence.

| Mode | How | Cost |
|------|-----|------|
| Off | Switch buttons open the other format at its own saved position | none |
| Estimated | Match audio chapters to EPUB table-of-contents entries by title (fuzzy), then interpolate by fraction within the chapter; fall back to overall fraction when titles do not line up | no new dependency or permission |
| Precise (Android only) | On "Switch", decode about 30 s of the audio around the position (Kotlin `MediaExtractor`/`MediaCodec`), transcribe with Android's `SpeechRecognizer` reading from a file descriptor (API 33+, on-device recogniser only), fuzzy-match the transcript against the EPUB text near the Estimated spot, jump to the best match | needs `RECORD_AUDIO` (unconfirmed) and an on-device language pack; see Open decisions |

Precise falls back to Estimated whenever it cannot produce a confident match, so Switch always works. Precise is hidden
off Android and disabled with an explanation when no on-device recogniser exists. It never sends audio off the device.

### Items

| # | Item | Approach | Size |
|---|------|----------|------|
| J0 | **Built 2026-11-11 (unit-tested; not exercised on a device).** Fix the shared `isFinished` | Readers send `isFinished` only on an explicit "Mark finished" or the audiobook's own finish, not at >= 99.5%; audio sync must not un-finish an ebook-finished item. Verify against the server first. | S |
| J1 | **Built 2026-11-12** Link model + auto-suggest | Stored in `KeyValueEntries` (no new table), candidate matching, confirm / unlink UI on the item page | M |
| J2 | **Item page built 2026-11-12; reader/Now Playing menus not yet** Switch buttons | "Read" / "Listen" on the item page and Now Playing / reader menus, using the link (or the same item) | S |
| J3 | **Built 2026-11-12** `SyncStrategy` + Estimated mode | Chapter/TOC matching and interpolation as pure functions with tests; settings row (Off / Estimated / Precise) | M |
| J4 | **Built 2026-11-12 (readers/player write on their own sync)** Keep progress in step | After a switch, write the mapped position to the other item's progress (not just locally), with the newest-wins rule from H3; never mark finished from the mapped value | M |
| J5 | Precise spike (done 2026-11-13 on the Pixel 8 Pro, Android 17; the emulator was not needed) | Confirm file-based `SpeechRecognizer` works on the AVD image, whether `RECORD_AUDIO` is required, and the language pack requirement; record findings. Build the real feature only if the spike passes and the policy decision allows it | M (spike S) |
| J6 | Precise mode (built 2026-11-13, verified on the Pixel) | Clip extraction, recognition, fuzzy match, confidence threshold, fallback | L |

**Precise, ebook to audio (added 2026-11-13).** Both directions use the same alignment. From the reader: take the words on screen (the first two or three lines at the top of the visible page, from `paragraphBounds`/`snippetY`), take the estimated audio time as a starting point, extract a clip of about 2 minutes around it, recognise it on the device, fuzzy-match the recognised words against the on-screen words, and start the audio at the matched time. If the match is weak (below the confidence threshold) or recognition isn't available, fall back to Estimated and say so ("approximate spot"). From the audio side it is the reverse: recognise a short clip at the current time and find those words in the book. Today's Estimated mode already works ebook -> audio (checked on the emulator: 65% in the book started the audio at 65%); Precise only improves how close it lands.

**J5 spike findings (2026-11-13, Pixel 8 Pro, Android 17):** the on-device recogniser (`SpeechRecognizer.createOnDeviceSpeechRecognizer`, Google's speech pack) accepts a file as audio: decode a clip with `MediaExtractor`/`MediaCodec` to 16 kHz mono 16-bit PCM and pass a pipe through `EXTRA_AUDIO_SOURCE`. It needs `RECORD_AUDIO` granted even though the microphone is never opened, and `<queries>` for `android.speech.RecognitionService`. Text arrives only as partial results (the final result covers just the first utterance, and segmented mode stops after it), so the transcript is built from the partials. Speed: 40 s of audio transcribes in about 2 s; opening a server file costs about 3 s once (the opened file is reused for a minute). Quality: names and endings are often wrong ("Paladin" for "Paladia"), so matching is fuzzy (first four letters, distinct words, a share-of-words score).

**J6 as built:** `PreciseRecognizer.kt` + `precise_match.dart` (matching, pure and tested) + `precise_service.dart` (channel, permission, streaming URL). Audio -> ebook: one 25 s listen at the saved audio time, found among all paragraphs (widening search), then the reader jumps there. Ebook -> audio: one listen at the percentage guess to see which paragraph the narrator is on, a jump by the word distance (2.6 words/s), then up to three 60 s confirming listens against the words on screen (about 20 s in all on the Pixel, against 50 s and a miss for a plain scan). Any failure keeps the Estimated spot and says so. Also used by "Play from here". Settings: Switch position -> Precise asks for the microphone permission and checks the recogniser. Progress shows as a centred glass card with a step counter. Works for English (`en-US`) only so far.

**Still open for Precise:** other languages (take the book's language), the audio-side switch from Now Playing's own Read button (uses the reader path, so it works), follow-mode drift correction (M6 proper: re-anchor while following), iOS (no equivalent plan yet), and a tolerance test with a second book.
| J7 | Tests | Pure-function tests for matching and interpolation, link table migration, `isFinished` rules, strategy fallback; emulator check of the switch flow on a linked pair | M |

### Decisions

1. **Linking source (decided):** match by ASIN, then ISBN, then fall back to normalised author + book title (series and
   sequence as tie-breakers). Applies to separate items; a single item that has both formats needs no matching.
2. **Precise mode permission (decided 2026-11-10):** `RECORD_AUDIO` is allowed for this opt-in mode if the J5 spike shows
   Android requires it. It is requested only when the user turns Precise on, with a short explanation first (the app
   does not record the microphone; Android's recogniser needs the permission), and Precise stays off if it is denied.
   Off and Estimated never need it. Check the Play data-safety form before release; Precise is Android-only, so iOS
   is unaffected.

## Phase K: Remaining roadmap (merged from the old build plan's unchecked items, 2026-11-10)

The old build plan (`git show a9e7ad8:PLAN.md`) held the build history; its open items live here. I compared every unchecked
box in it against this plan. Some of its "Deferred" notes are stale: K1, K2 and K8 below turned out to be built already, as are filter/sort and the
Authors / Collections / Playlists sections (D1). Check the code before building anything below.

### New work (not covered by phases A-J)

| # | Old plan ref | Item | Notes | Size |
|---|---------|------|-------|------|
| K1 | 5.8 | **Built (found in code 2026-11-11; not re-verified on the emulator).** Audio bookmarks | The server stores them (`time` + `title`, per user); list, add, rename, delete and jump from Now Playing. Pairs with the device-only ebook bookmarks in H5. | M |
| K2 | 4.7 | **Built (found in code 2026-11-11; not re-verified).** Search: Authors / Narrators / Tags / Genres | `GET /api/libraries/:id/search` already returns these groups; needs a destination for each tap (author page exists; others filter the library). | M |
| K3 | 11.1 | Chromecast (Android only) | **Skipped for now (decided 2026-11-10); tracked in ROADMAP To do.** Needs a Cast SDK package, which breaks the first-party-only rule. | XL |
| K4 | 11.2 | Home-screen / lock-screen playback widget | Android App Widget in Kotlin (no package); iOS widget needs the Mac. | L |
| K5 | 11.3 | Tablet / foldable layouts | Responsive breakpoints for Home, detail and Now Playing. | L |
| K6 | 11.4 | More skins | After F1 (theme variants) so each skin gets light/dark/black for free. | M |
| K7 | 11.5 | Custom-time playback start and other power-user options | Seen in the reference app; scope when picked up. | S |
| K8 | 5.13 | **Built (setting `keepScreenAwake` exists; not re-verified).** Keep-screen-awake toggle for Now Playing | Small; `wakelock_plus` is already used by the reader. Lock-player UI and MP3 index seeking stay excluded (see the top of this file). | S |
| K9 | 12.3 | **Built 2026-11-12** Versioning / changelog convention | `CHANGELOG.md` and `RELEASING.md` (versioning, changelog rule, release checklist including Phase L). | S |
| K10 | 2.5 | Shared skin-aware widget set (buttons, sheets, tab bar) | Overlaps the F1 colour audit; do together. | M |

### Already covered elsewhere in this plan

3.3 multi-server -> E2 · 3.8 mask server address -> A3 · 4.5 collapse series -> D5 · 9.9 splash -> F3 (app icon still needs
artwork) · 10.5 / 10.7 Android Auto settings and voice -> F5 · 2.5 contrast and theme audit -> F1/F2.

### Blocked (not planned)

- **Admin permissions on the server:** 7.3 add podcast, 7.4 auto-download, 8.5 primary/supplementary ebook, 8.6 send to
  Kindle (needs server SMTP), 9.1 RSS feeds.
- **Mac / Apple access:** 10.8-10.12 CarPlay and Siri, 12.1 macOS CI, 12.2 store listings, 12.4 TestFlight/Play beta.
- **Needs artwork:** 9.9 real app icon (also revisit the `image` package pin conflict with `epub_view`).
- **Needs a second language first:** 12.5 localization QA (F4 ships English only).
- **Excluded by decision:** 5.11 volume-key navigation, MP3 index seeking, lock-player UI.

## Phase L: Store listings and permissions (needs the user: console access)

Added 2026-11-12. Every permission, background mode or data use this plan adds must be declared accurately in the Google
Play Console and App Store Connect before the build that uses it ships. I can prepare the text and the checklist from
the code; the user submits it (I have no console access). Do this once G7 and J5/J6 are decided, and again before each
release (ties to K9).

| # | Item | Approach | Size |
|---|------|----------|------|
| L1 | Inventory what the build actually uses | List from the merged Android manifest and `Info.plist`: Android `INTERNET`, `WAKE_LOCK`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, and `RECORD_AUDIO` if Precise ships; iOS background audio mode and notification authorization. Also list what data the app stores or sends: account name and token to the user's own server, listening and reading progress, listening sessions, reading time (on device only), ebook/audiobook links (on device only), logs (on device). | S |
| L2 | Google Play Console | Update the **Data safety** form (data types, whether collected or shared, encryption in transit, deletion); the **foreground service** declaration (media playback) with its justification; the **`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`** justification (Play restricts it: give the core-function reason or drop it); the **`POST_NOTIFICATIONS`** use for reminders; the **`RECORD_AUDIO`** sensitive-permission explanation and the in-app prominent disclosure if Precise ships (on-device recognition, audio never leaves the device); the privacy policy URL; the content/target-audience answers if they change. | M |
| L3 | App Store Connect | Update **App Privacy** (data types and whether linked to the user: the app sends data only to the server the user configures, decide and record how that is declared); background audio justification and review notes with demo server credentials; notification use for reminders; check whether any new "required reason" API is used (privacy manifest). Precise is Android-only, so no microphone usage string is added on iOS. | M |
| L4 | Store listing text and screenshots | "What's new" and description for: linked ebook/audiobook switching, streaks and reminders (optional), library icons and the new Home menu, reader fixes. Refresh screenshots (Home header, link row, Settings). Mention optional permissions as optional. | S |
| L5 | Privacy policy text and in-app disclosure | Update the policy for: reading time and links stored on the device, reminders, microphone use for Precise (if shipped), logs. Make sure each permission prompt is preceded by an in-app explanation (reminders and Precise already require one). | S |
| L7 | Website | Update the published policies and pages so they match the listings: privacy policy (the same changes as L5), terms if any, and the support/FAQ and feature pages for linking, streaks, reminders and Precise (what each permission is for and how to turn it off). The privacy policy URL given to Google Play and App Store Connect must be this page, so publish it **before** submitting L2/L3. The site is the separate **Steeped-Site** repo (`~/Code/Steeped-Site`, Cloudflare Worker; the privacy policy is `src/worker/pages/privacy.ts`, served at `/privacy`). I draft the wording and the edit there; the same rule applies as for this repo (no push without being asked). | S-M |
| L6 | Release checklist | Add L1-L5 and L7 to the K9 release checklist: after any dependency or manifest change, diff the merged manifest against the last release and update the console answers before submitting. | S |

## Phase M: Read and listen at the same time (planned 2026-11-13)

Audio already keeps playing while you read (it runs in the background service), so what is missing is control and sync inside the reader. Three levels, each useful on its own:

1. **Dock** - control the audio without leaving the page.
2. **Follow** - the page tracks the audio (read-along).
3. **Tap to hear** - tap a paragraph, the audio jumps there.

Only linked books get 2 and 3 (Phase J gives the chapter map). An unlinked ebook still gets the dock if something is playing.

### Layout (phone, portrait)

- **Collapsed dock** (default while audio is loaded): one 52 px row docked to the bottom *inside* the reader chrome, above the progress bar: play/pause, -15 s, +30 s, a thin progress bar with chapter time left, and an expand handle. It counts as covered area, so page turns and the "text under the bars" maths keep working.
- **Expanded dock** (tap or swipe up): a bottom sheet over the lower 40% with chapter title, speed, sleep timer, chapter skip and the Follow toggle. Swipe down to collapse.
- **Follow chip** top centre of the page: "Following audio" (on) / "Follow" (off) / "Re-sync" (shown after the reader scrolled away from the audio). One tap each.
- **Spot marker**: a thin accent band on the left margin at the paragraph the audio is reading (estimated; see accuracy below). In Follow the page scrolls so the band sits at about 30% down.
- **Landscape / tablet**: reader on the left (about 60%), a fixed player column on the right (cover, chapter, controls). No dock needed.
- **Now Playing -> Read along** (the reverse direction): below the cover, a 3-5 line text window around the current position that scrolls with the audio; tap it to open the reader at that spot. Replaces nothing; it is an option under the existing Read button.

Rejected: a floating video-style window (covers text, awkward gestures), and splitting a portrait phone screen in half (too little text per screen).

### How the sync works

- Audio position -> chapter span (already built: `ChapterSpan`, `AudioPoint`) -> paragraph by word-count interpolation within the chapter (`reader_math` words per paragraph) -> `_revealIn(index)` (the jump helper added 2026-11-13).
- The reader reads the live `playbackPositionProvider`; throttle to about one update per second and only move when the audio paragraph changes.
- Any manual scroll or page turn switches Follow off and shows "Re-sync" (never fight the finger). Page turns while following still work; they just detach.
- Tap to hear: long-press a paragraph -> "Play from here" (reuses the selection toolbar item); a short tap stays page-turn/bar toggle. The audio seeks to the paragraph's estimated time.
- Single source of truth: while Follow is on, the audio position drives the saved ebook position (write both from the player's progress sync); the reader's own periodic save is skipped so the two don't ping-pong. With Follow off they save independently as today.

### Accuracy

Interpolation drifts within a chapter (narration speed, front matter, abridged audio). Expect a paragraph or two of error, and visibly more where an edition differs. Mitigations: show the spot marker as a soft band, not a line; correct on "Play from here" (store the audio/paragraph pair as an anchor and interpolate between anchors); the Precise mode already planned in J5/J6 (on-device speech recognition matched against the text) is the proper fix and plugs in as another `SyncStrategy`.

### Steps

- M1 (built, untested on a device) Dock: collapsed/expanded, play/pause, skips, speed, sleep timer; counted as covered area; hidden when nothing is playing.
- M2 (built, untested on a device) Follow: position -> paragraph, marker band, scroll, Follow/Re-sync chip, detach on manual scroll.
- M3 (built, untested on a device) Play from here (long-press) plus anchors that refine the estimate.
- M4 (built, untested on a device) Now Playing read-along window (reverse direction).
- M5 (built 2026-11-13, untested on a device) Landscape/tablet split: at 720 dp wide or more the strip becomes a 320 dp player column beside the page (`ReaderPlayerPanel`).
- M6 Precise alignment (needs J5/J6).
- M7 (built) Streaks and stats: reading and listening at the same time must count wall-clock minutes once per day (union of the two sessions), not twice; the "keep screen on" setting stays the reader's own.
- M0 (built 2026-11-13, untested on a device) Switch-button drop-down (above) and the "When switching" setting.
- M8 Settings: Follow on by default for linked books (on/off), dock on/off, marker on/off. Strings, tests (pure position->paragraph mapping, anchors, dedupe of minutes), emulator check with the Pi pair.

**Decided 2026-11-13:** the dock appears only for the linked audiobook of the book being read (never for something unrelated that happens to be playing).

**Switch button asks first.** The quick-switch button (Listen in the reader, Read in Now Playing) opens a small drop-down menu instead of switching straight away:

- In the reader (Listen button): "Switch to audiobook" (today's behaviour: close the reader, open Now Playing at the matching spot) or "Listen while reading" (stay on the page, start the audio at the matching spot, show the dock with Follow on).
- In Now Playing (Read button): "Switch to ebook" (today's behaviour) or "Read along" (stay on Now Playing, show the read-along text window; its tap opens the reader with the dock).
- If the linked audio is already playing, the reader's menu shows "Show player" (open the dock) in place of "Listen while reading".
- Remember the last choice in settings ("When switching: ask / always switch / always both") so a regular user can make it one tap; the menu stays reachable by long-press.
- Switching must still change screens immediately (the quick-switch spinner rule); "Listen while reading" starts the audio behind the page.


## Phase N: Precise on iOS (DRAFT 2026-11-13, awaiting the user's approval of section N2)

Cannot be built or run on the Linux machine: needs a Mac with Xcode 26 and an iPhone on iOS 26 or later. Reference for the integration: `~/Code/AudioBooth` (MPL 2.0: ideas yes, copying Swift code no).

### N1. What AudioBooth shows about integrating Apple's recogniser

- **API:** iOS 26+ only, `SpeechAnalyzer` + `SpeechTranscriber` (module `Speech`), gated with `#available(iOS 26, *)` and `SpeechTranscriber.isAvailable`. Their app target is iOS 18 with the feature weak-linked; ours stays at 15 and `available` simply answers false below 26.
- **Language model:** `SpeechTranscriber.supportedLocale(equivalentTo:)`, then `AssetInventory.status(forModules:)`; if not installed, `assetInstallationRequest(supporting:)` + `downloadAndInstall()` with a progress poll, then `AssetInventory.reserve(locale:)` (evicting another reserved locale if full). First use therefore needs a "Preparing speech model" step with progress.
- **Transcriber:** `SpeechTranscriber(locale:, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])`; each result run carries an `audioTimeRange`, so **every word has its start time**.
- **Feeding audio:** `AVAssetReader` over the local file, buffers converted to `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)`, yielded into an `AsyncStream<AnalyzerInput>` (`AnalyzerInput(buffer:, bufferStartTime:)`), `analyzer.start(inputSequence:)`, results read from `transcriber.results`, end with `finalizeAndFinishThroughEndOfInput()`; cancel with `cancelAndFinishNow()`. `SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering)` for short interactive samples.
- **Source:** downloaded audiobooks only (`track.localPath`); there is no streaming path.
- **Permission:** `NSSpeechRecognitionUsageDescription` in Info.plist (no microphone string).
- **Sampling:** 15-30 s clips, at least 12-20 words, alignment score 0.5, collected until a deadline or a 25-90 s read ceiling.

### N2. Proposed logic changes (each needs the user's yes)

First version, same logic as Android, only what iOS requires:
- **A1. Same channel contract**, Swift plugin `PreciseRecognizer.swift` answering `available` / `recognize` (streaming `partial {id, text, audioMs}`) / `cancel`; Dart unchanged except the points below.
- **A2. Availability and permission per platform:** on iOS `available` = iOS 26+ and a supported locale; the permission step asks for speech recognition instead of the microphone; a `prepare` call installs and reserves the language model with progress (new "Preparing speech model" dialog, shown once).
- **A3. Audio source on iOS = downloaded files only** (like AudioBooth) in version 1; Settings says "Download the audiobook to use Precise" when it is not. Streaming from the server on iOS comes later.
- **A4. Partial results:** `reportingOptions: [.volatileResults]` so early stop works; `audioMs` comes from the real word end times (more accurate than Android's estimate). To be confirmed on a device.

Optional improvements, each separately (both platforms unless said):
- **B1. Use real word times where the platform gives them** (iOS): the audio time is the matched word's own start, not a proportional guess, so the confirming listens can be dropped. (Android could approximate this from when words first appear: "word clock".)
- **B2. Ordered alignment instead of bag-of-words:** candidates from an index of rare words, then a local dynamic-programming alignment with penalties for skipped and wrong words and a bonus near the expected place (AudioBooth's `TranscriptAligner`). Gives the exact first word, a cleaner confidence, and faster searches.
- **B3. Chapter-title mapping like AudioBooth's:** Roman numerals, spelled-out numbers past 20, a unique "contains" match, a confidence (high/medium/low) that sets the search radius (45/120/240 s), and several candidate guesses tried in turn instead of the plain window scan as the fallback.
- **B4. "The narrator is N pages ahead/behind - jump?" banner** in the reader (AudioBooth's Position Sync), shown only when you are more than about 600 words away.
- **B5. Live read-along from streaming results** to correct Follow's drift (AudioBooth transcribes up to 5 minutes ahead of the playhead).

Recommendation: build A1-A4 first (least risk when testing on a device), then B1 and B2 once iOS works, B3 next, B4 and B5 last.

**Status 2026-11-13: A1-A4 written, not yet compiled or run.** Linux side done: `ios/Runner/PreciseRecognizer.swift` (in the Xcode project, registered in `AppDelegate`), `NSSpeechRecognitionUsageDescription`, the `PERMISSION_SPEECH_RECOGNIZER` Podfile macro, Dart `Platform.isIOS` branches in `precise_service.dart` (speech permission, downloaded file path instead of stream URL, `precisePrepare` with progress) and the Settings flow (permission, then a "Preparing speech model" dialog). Next, on the Mac: build for the simulator to compile the Swift (N3 list), then run on an iPhone when one is available. B1-B5 are not started.

### N3. Things I cannot confirm from here (check on the Mac)

- The exact initialiser and option names for volatile results with `SpeechAnalyzer` on a custom input sequence; whether partials arrive before the 15 s finalisation AudioBooth uses.
- Whether recognition needs the speech-permission prompt at all with `SpeechTranscriber`.
- Speed of the iOS recogniser relative to playback (Android: about 20x).
- That Steeped's CI image has Xcode 26 (needed to compile the iOS 26 symbols).
- `engineBridge.applicationRegistrar.messenger()` as the way to create the channel in `didInitializeImplicitFlutterEngine` (documented by Flutter, not tried here).

## Suggested order

A (A1, A4, A3, A5, A2) -> B1 -> B2/B3/B4 -> C1/C2 -> B6/B5 -> D1/D2/D4/D3/D5 -> F3 -> F1/F2 -> E1 -> F5 -> F4 -> E2. Phase I (listening sessions) is already built (see its status note); only the I4 offline-queue check and the I5 timezone rule remain. Phase G (streaks) comes next: G1 -> G2/G3 -> G4 -> G5 -> G7 (reminders), with the G6 spike last. Phase L (store listings) follows G7 and J5/J6 and repeats before every release. Phase J (linking): J0 -> J1 -> J2 -> J3 -> J4 -> J7, with J5/J6 (Precise) last. Phase V (verification) runs before all of this. Phase H: H7 is a small, quick win and can go first; H8-H10 are optional follow-ups to the reader.
Small, high-visibility items first; the two large items (E2 multi-server, F4 translations) last.

## Settings matrix (every preference gets a control)

| Setting | Section | Default |
|---|---|---|
| Jump back / jump forward seconds (A1) | Playback | 30 / 30 (migrated from today's value) |
| Cellular streaming / downloads: Ask, Always, Never (A2) | Data | Always (today's behaviour) |
| Treat metered Wi-Fi like cellular (E1) | Data | Off |
| Mask server address (A3) | Account | Off |
| Allow seeking on lock-screen controls (A5) | Playback | On |
| Auto-rewind amount; scale after long pauses (B1) | Playback | Off; off |
| Sleep timer: end of chapter available, fade-out on/length, chime on/off, extend minutes, auto window on/start/end (B2-B6) | Sleep Timer | existing behaviour; fade on, chime on, auto window off |
| Show sync-failed indicator (C2) | Advanced | On |
| Remember library section / collapse series (D1, D5) | Library (new section) | On / Off |
| Theme: follow system / light / dark / black (F1) | Appearance | Dark |
| Ask before switching server while playing; show other servers' downloads (E2) | Account | On / On |
| Android Auto: browse grouping limit, series order (F5) | Android Auto (new section) | server defaults |
| Show streak on Home (G5) | User Interface | On |
| Streak bar: any activity or daily goal minutes (G3) | Streaks (new section) | Any activity |
| Forgive a missed day; weekly streak mode (G4) | Streaks | On; off |
| Streak reminder: on/off, time, quiet hours (G7) | Streaks | Off |

## Decisions (resolved 2026-10-07)

- Auto-rewind default: **Off**. Shake-to-restart: **dropped**, replaced by quick extend (B5).
- Metered: **label plus a setting** (E1). Multi-server: **built now**, downloads kept per server and shown together offline (E2).
- Translations: **setup only**, en-US stays the only language (F4). Podcast playlists: **deferred**.
- Dependencies: **first-party only**; none planned.

- **Streaks (Phase G):** researched 2026-11-09; open decisions are listed in the phase. Reading and listening count
  together; device-only until the G6 spike says otherwise.

## Also resolved

- **E2 remove-profile:** ask each time whether to delete that server's downloads (default choice: keep).
- **F5 Assistant voice:** build the `onPlayFromSearch` hook; shipping without a real Google Assistant device test is accepted.

## Risks

- Audio features can't be heard on Linux, so they rely on unit tests plus a phone check.
- Changing cellular settings from bool to enum touches both streaming and downloads; migration must be tested.
- Multi-server touches session, socket, storage and every cache; it lands last on its own sub-branch, and the drift migration needs a tested rollback story (keep a backup copy of the database before migrating).
