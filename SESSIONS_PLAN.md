# Listening sessions & streak plan

## Why sessions and streak don't update

The app only ever calls the sessionless `PATCH /api/me/progress/:id`
(`progress_repository.dart`, called from `PlaybackController`'s 15 s tick, on
pause, and on finish). That updates *where you are in a book*. It does **not**
create an Audiobookshelf listening session, and the server derives everything
else from sessions:

| Screen | Server data | Written by |
|---|---|---|
| History / Recent sessions | `/api/me/listening-sessions` | playback sessions |
| 7-day chart, best day, daily average, days listened | `listening-stats.days` | `timeListened` sent to `/api/session/:id/sync` and `/close` |
| By day of week | `listening-stats.dayOfWeek` | same |
| Year in review | sessions + `days` | same |
| Streak (`currentStreakDays`) | computed client-side from `days` | same |

So no sessions means no new `days` entries, which means the streak stops at the
last day the official app (or an older build) logged, and History never grows.
The streak code itself is fine; it has nothing to count.

Verified earlier against the live account: 1228 sessions, 573 days, 6-day
streak. Those came from other clients.

## What we need

A real session lifecycle alongside the existing progress PATCH.

1. **Open a session** when playback starts: `POST /api/items/:id/play`
   (podcast episode: `/api/items/:id/play/:episodeId`) with
   `{deviceInfo:{clientName:'Steeped',...}, forceDirectPlay:true, forceTranscode:false, supportedMimeTypes:[...]}`.
   Keep the returned session `id`. We keep using our own URLs for audio
   (direct play), so ignore the returned tracks.
2. **Sync** every 15 s tick and on pause: `POST /api/session/:id/sync` with
   `{timeListened, currentTime, duration}`. `timeListened` is wall-clock seconds
   actually played since the previous sync (not position delta; seeking must not
   count, and 2x speed counts real time).
3. **Close** on stop, item switch, finish, and app teardown:
   `POST /api/session/:id/close` with the same body. Close the old session
   before opening the next.
4. **Keep the PATCH progress call** as the source of truth for position and the
   offline queue; the session call is additive. If the session calls fail, they
   must never block or delay playback (same 10 s cancel deadline as progress).
5. **Offline / downloaded listening**: accumulate `timeListened` locally and
   upload later with `POST /api/session/local` (one session) or
   `/api/session/local-all` (batch), as the official app does. This needs a new
   drift table next to `PendingProgressSyncs`, per profile (QOL E2), drained by
   `pending_sync_controller.dart`.
6. **Streak correctness fixes (client)**:
   - `days` keys are in the *server's* timezone; `currentStreakDays` and the
     7-day chart use the device's local date. Decide on one rule (use the device
     date, and send `timeListened` so the server buckets it; accept an edge
     mismatch near midnight) or read the server's `today` field.
   - Show the streak from the freshly fetched stats after a session closes
     (invalidate `listeningStatsProvider` and the history provider on close, and
     on returning to Stats/History).
7. **Stats refresh**: `listeningStatsProvider` is `autoDispose`, so it refetches
   on open; the History controller loads once in `build()`. Add a pull-to-refresh
   and reload on screen focus.

## Steps

0. **Verify the endpoints** against audiobooks.dev (`demo`/`demo`) with a
   throwaway session: open, sync with 30 s, close, then read
   `listening-stats`, and confirm `days[today]` increased and the session
   shows in `listening-sessions`. Also confirm what `/play` returns for a
   direct-play item and whether `forceDirectPlay` avoids a transcode. I wrote
   this plan from knowledge of the Audiobookshelf API; none of it is checked
   yet.
1. `SessionRepository` (`data/session_repository.dart`): `open`, `sync`,
   `close`, using the same deadline helper as `ProgressRepository`.
2. `PlaybackController`: hold `_sessionId` and `_lastSessionTick`; track played
   seconds with a stopwatch driven by the existing `playing` stream (pause and
   buffering stop it; speed scales nothing).
3. Wire open/sync/close into `playItem`, the sync tick, pause, finish,
   item switch.
4. Offline queue table + migration, drain on reconnect, local-all upload
   (needs a drift schema bump and the pre-migration backup already in place).
5. Streak/date handling and refresh behaviour (items 6 and 7).
6. Tests: fake `SessionRepository`; played-seconds accounting (pause, seek,
   speed, rapid item switch); close-on-switch; failure never blocks playback;
   streak across local midnight and month boundaries.
7. Live check on a device: listen 2 minutes, confirm a new row in History
   and today's bar and streak update.

## Risks / open questions

- Double counting: if `/play` or the session sync also moves progress, it could
  fight the PATCH. Verify in step 0; if so, drop the PATCH while online.
- `/play` for a very large library or transcode-capable server may do extra
  work; direct play flags should keep it cheap.
- Podcasts (episode path) and ebooks: ebooks should not open listening
  sessions.
- Linux desktop playback can't test any of this until the mpv backend works;
  use the Android build.
