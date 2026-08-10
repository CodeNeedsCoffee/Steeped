import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show PlayerException;

import '../../../core/audio/audio_handler_provider.dart';
import '../../../core/audio/steeped_audio_handler.dart';
import '../../../core/logging/log_repository.dart';
import '../../../core/network/audio_stream_url.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/audio_track.dart';
import '../../../models/bookmark.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/podcast_episode.dart';
import '../../auth/state/session_controller.dart';
import '../../auth/state/session_state.dart';
import '../../downloads/state/download_controller.dart';
import '../../library/state/library_providers.dart';
import '../../localmedia/state/local_media_providers.dart';
import '../../settings/data/app_settings.dart';
import '../../settings/state/settings_providers.dart';
import '../data/bookmark_repository.dart';
import '../data/progress_repository.dart';
import 'pending_sync_controller.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(dioProvider));
});

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository(ref.watch(dioProvider));
});

/// PLAN.md Phase 5.8: bookmarks for one library item. Callers invalidate
/// `bookmarksProvider(libraryItemId)` after a create/delete to refetch —
/// cheap since the list is small and only fetched while the sheet is open.
final bookmarksProvider = FutureProvider.autoDispose
    .family<List<Bookmark>, String>((ref, libraryItemId) {
      return ref
          .watch(bookmarkRepositoryProvider)
          .fetchBookmarks(libraryItemId);
    });

/// The item currently loaded into the player, or null if nothing is
/// playing — drives whether the mini-player shows at all.
final currentPlaybackItemProvider = StateProvider<LibraryItemDetail?>(
  (ref) => null,
);

/// PLAN.md Phase 5.14: the id of whatever [PlaybackController.playItem] /
/// [PlaybackController.playEpisode] / [PlaybackController.playLocalMedia] is
/// currently fetching/loading, or null. Keyed the same way as
/// [LibraryItemDetail.downloadId] (plain item id, or `id::episodeId` for a
/// podcast episode) so a Play button anywhere can show its own loading state
/// instead of appearing to do nothing during the network-fetch-then-buffer
/// gap before audio actually starts.
final playbackLoadingIdProvider = StateProvider<String?>((ref) => null);

/// True while [PlaybackController._recoverFromPlayerError] is actively
/// retrying a dropped stream (stale token, network blip, server restart —
/// see that method's doc comment). Surfaced on Now Playing's play/pause
/// button via the same [PlaybackLoadingBadge] the Phase 5.14 loading spinner
/// uses, so an automatic reconnect shows visible feedback instead of
/// silently retrying with the button just sitting there.
final isReconnectingProvider = StateProvider<bool>((ref) => false);

final playbackPositionProvider = StreamProvider<double>((ref) {
  return ref.watch(audioHandlerProvider).globalPositionStream;
});

final isPlayingProvider = StreamProvider<bool>((ref) {
  return ref.watch(audioHandlerProvider).playbackState.map((s) => s.playing);
});

/// PLAN.md Phase 9.3: backs the "scale elapsed time by speed" display
/// option — needs the live speed, not just the value the speed dropdown
/// last set locally.
final playbackSpeedProvider = StreamProvider<double>((ref) {
  return ref
      .watch(audioHandlerProvider)
      .playbackState
      .map((s) => s.speed == 0 ? 1.0 : s.speed);
});

/// PLAN.md Phase 5.7/9.3: time left on an active sleep timer, or null if
/// none is running. A real, working (if basic) timer — manual duration
/// only; end-of-chapter/shake-to-reset/fade-out are still deferred.
final sleepTimerRemainingProvider = StateProvider<Duration?>((ref) => null);

/// PLAN.md Phase 5.9: syncs progress every 15s while playing (no
/// metered/unmetered throttling like the reference app does — deferred,
/// not core to proving playback works) plus on every pause.
///
/// The sync timer is driven by [SteepedAudioHandler.playbackState]'s
/// `playing` flag rather than by explicit start/stop calls from [pause]/
/// [resume] — those only fire for in-app UI taps. A hardware media button,
/// the notification's pause action, or a headset button all call the
/// handler's `pause()`/`play()` directly (that's the whole point of
/// exposing a MediaSession), bypassing this class entirely. Tying the timer
/// to actual playback state means it stops the moment audio actually stops,
/// regardless of what stopped it — a previous version didn't, which let a
/// stale position keep syncing to the server after a hardware pause.
class PlaybackController extends Notifier<void> {
  Timer? _syncTimer;
  Timer? _sleepCountdown;
  StreamSubscription<PlaybackState>? _playbackStateSub;
  bool _wasPlaying = false;

  /// Debugging note (2026-08-03): tracks whether the periodic sync tick
  /// below is seeing real position progress. Reset every time
  /// [_startSyncTimer] (re)starts, so a fresh play always starts from a
  /// clean slate.
  double? _lastSyncedPosition;
  int _staleSyncTicks = 0;

  /// Bounds the auto-retry in [_recoverFromPlayerError].
  ///
  /// Bug fix 2026-08-05 (evan: playback "staggering"). This used to be reset
  /// inside [_startSyncTimer] — which [_recoverFromPlayerError] itself calls
  /// after a successful reload, so every recovery handed itself a fresh
  /// budget and the "bounded to 2 attempts" bound never actually bound
  /// anything. On a flaky connection (the state the log's `receive timeout` /
  /// `Failed host lookup` entries describe) the result was an unbounded
  /// error -> reload -> brief playback -> error loop, each iteration tearing
  /// down and re-preparing the whole ExoPlayer playlist and re-seeking. That
  /// loop *is* the staggering: not one clean failure, but a reload every few
  /// seconds. Now only a genuinely fresh start ([_resetPlaybackHealth], from
  /// the play* entry points and an explicit user [resume]) or a sustained
  /// stretch of healthy playback ([_healthyTicksSinceError]) restores it.
  int _playerErrorRetryCount = 0;

  /// Consecutive advancing sync ticks since the last player error. `just_audio`
  /// can emit several errors for one underlying failure, and a recovered
  /// stream that dies again 5s later is not "recovered" — requiring ~1 minute
  /// of real progress before clearing [_playerErrorRetryCount] is what stops a
  /// half-working stream from cycling forever.
  int _healthyTicksSinceError = 0;

  /// Guards against overlapping recoveries: `errorStream` frequently emits
  /// more than once for a single dropped connection, and each event used to
  /// start its own independent `loadItem` + seek + play sequence racing the
  /// others on the same player.
  bool _recoveryInFlight = false;

  /// Guards against overlapping progress syncs. The 15s [Timer.periodic]
  /// fires regardless of whether the previous tick's request finished, so a
  /// slow server used to accumulate concurrent in-flight PATCHes — extra load
  /// aimed at the one server the audio stream also needs.
  bool _syncInFlight = false;

  /// Consecutive failed syncs, and how many 15s ticks to skip before trying
  /// again. Retrying a down server every 15s forever accomplishes nothing the
  /// durable queue (PLAN.md Phase 6.7) doesn't already cover, so failures back
  /// off exponentially (15s -> 30s -> 60s -> 120s, capped) instead.
  int _consecutiveSyncFailures = 0;
  int _syncBackoffTicks = 0;

  /// De-noises the log during an outage: without this, one 20-minute bad patch
  /// wrote ~80 near-identical "Sync failed" rows, evicting everything else
  /// from the 500-entry cap and burying whatever actually needed reading.
  String? _lastSyncErrorKind;

  @override
  void build() {
    _playbackStateSub = _handler.playbackState.listen(_onPlaybackStateChanged);
    ref.onDispose(() {
      _syncTimer?.cancel();
      _sleepCountdown?.cancel();
      _playbackStateSub?.cancel();
    });
  }

  void startSleepTimer(Duration duration) {
    _sleepCountdown?.cancel();
    var remaining = duration;
    ref.read(sleepTimerRemainingProvider.notifier).state = remaining;
    _sleepCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        timer.cancel();
        ref.read(sleepTimerRemainingProvider.notifier).state = null;
        pause();
      } else {
        ref.read(sleepTimerRemainingProvider.notifier).state = remaining;
      }
    });
  }

  void cancelSleepTimer() {
    _sleepCountdown?.cancel();
    _sleepCountdown = null;
    ref.read(sleepTimerRemainingProvider.notifier).state = null;
  }

  SteepedAudioHandler get _handler => ref.read(audioHandlerProvider);

  void _onPlaybackStateChanged(PlaybackState state) {
    if (state.playing == _wasPlaying) return;
    _wasPlaying = state.playing;
    final item = ref.read(currentPlaybackItemProvider);
    if (item == null) return;
    if (state.playing) {
      _startSyncTimer(item);
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
      _sync(item);
    }
  }

  /// PLAN.md Phase 6.6: a downloaded copy is preferred over streaming
  /// whenever one exists — not just as an offline fallback, but always,
  /// since it's faster and uses no data. This is also what makes offline
  /// playback genuinely work with zero connectivity: [downloadRepo]
  /// rebuilds the whole playable item from local rows, no network call.
  Future<void> playItem(String itemId) async {
    ref.read(playbackLoadingIdProvider.notifier).state = itemId;
    _resetPlaybackHealth();
    try {
      final downloadRepo = ref.read(downloadRepositoryProvider);
      final LibraryItemDetail item;
      final List<Uri> sourceUris;

      if (await downloadRepo.isDownloaded(itemId)) {
        final offlineItem = await downloadRepo.buildOfflineItemDetail(itemId);
        final localTracks = await downloadRepo.localTracksFor(itemId);
        if (offlineItem == null ||
            localTracks.isEmpty ||
            localTracks.any((t) => t.localPath == null)) {
          return;
        }
        item = offlineItem;
        sourceUris = localTracks.map((t) => Uri.file(t.localPath!)).toList();
      } else {
        final session = ref.read(sessionControllerProvider);
        if (session is! SessionAuthenticated) return;
        if (await _blockedByCellularSetting()) return;
        final fetched = await ref
            .read(libraryRepositoryProvider)
            .fetchItemDetail(itemId);
        if (fetched.isPodcast || fetched.tracks.isEmpty) return;
        item = fetched;
        sourceUris = _streamSourceUris(fetched.tracks, session);
      }

      ref.read(currentPlaybackItemProvider.notifier).state = item;
      await _handler.loadItem(
        item: item,
        sourceUris: sourceUris,
        startPosition: await _resolveStartPosition(item),
      );
      _handler.onItemFinished = () => _onFinished(item);
      _handler.onPlayerError = (e) => _onPlayerError(item, e);
      // Not awaited: `AudioPlayer.play()`'s Future only completes once
      // playback pauses/stops/completes (see just_audio's doc comment) — the
      // `player.playing` flag it sets flips synchronously, well before that,
      // which is what `playbackState`'s listener above and
      // [playbackLoadingIdProvider]'s consumers actually care about.
      // Awaiting it here would keep this whole method (and the loading
      // indicator tied to it) pending for the entire playback session.
      unawaited(_handler.play());
      _startSyncTimer(item);
    } catch (e) {
      unawaited(
        ref
            .read(logRepositoryProvider)
            .log('error', 'playback', 'Failed to start playback for $itemId: $e'),
      );
      rethrow;
    } finally {
      if (ref.read(playbackLoadingIdProvider) == itemId) {
        ref.read(playbackLoadingIdProvider.notifier).state = null;
      }
    }
  }

  /// PLAN.md Phase 7.5: play a single podcast episode. A downloaded copy is
  /// preferred (same rule as [playItem]) — [playItem] with the episode's
  /// [downloadId] reconstructs it from local rows with no network. Otherwise
  /// the episode's own `audioTrack` is streamed as a one-track item whose id
  /// stays the parent podcast's (so cover + progress endpoints resolve), with
  /// [episodeId] set so progress routes to the per-episode sync path.
  Future<void> playEpisode(
    LibraryItemDetail podcast,
    PodcastEpisode episode,
  ) async {
    final downloadId = '${podcast.id}::${episode.id}';
    ref.read(playbackLoadingIdProvider.notifier).state = downloadId;
    _resetPlaybackHealth();
    try {
      final downloadRepo = ref.read(downloadRepositoryProvider);
      if (await downloadRepo.isDownloaded(downloadId)) {
        await playItem(downloadId);
        return;
      }

      final session = ref.read(sessionControllerProvider);
      if (session is! SessionAuthenticated) return;
      if (await _blockedByCellularSetting()) return;
      final track = episode.audioTrack;
      if (track == null) return;

      final item = LibraryItemDetail(
        id: podcast.id,
        mediaType: 'podcast',
        coverPath: podcast.coverPath,
        updatedAt: podcast.updatedAt,
        title: episode.title,
        subtitle: podcast.title,
        authors: podcast.authors,
        narrators: const [],
        series: const [],
        genres: const [],
        description: episode.description,
        publishedYear: null,
        duration: episode.duration ?? track.duration,
        chapters: const [],
        hasEbook: false,
        progress: episode.progress,
        tracks: [track],
        episodeId: episode.id,
      );

      ref.read(currentPlaybackItemProvider.notifier).state = item;
      await _handler.loadItem(
        item: item,
        sourceUris: _streamSourceUris([track], session),
        startPosition: await _resolveStartPosition(item),
      );
      _handler.onItemFinished = () => _onFinished(item);
      _handler.onPlayerError = (e) => _onPlayerError(item, e);
      // Not awaited: `AudioPlayer.play()`'s Future only completes once
      // playback pauses/stops/completes (see just_audio's doc comment) — the
      // `player.playing` flag it sets flips synchronously, well before that,
      // which is what `playbackState`'s listener above and
      // [playbackLoadingIdProvider]'s consumers actually care about.
      // Awaiting it here would keep this whole method (and the loading
      // indicator tied to it) pending for the entire playback session.
      unawaited(_handler.play());
      _startSyncTimer(item);
    } catch (e) {
      unawaited(
        ref
            .read(logRepositoryProvider)
            .log(
              'error',
              'playback',
              'Failed to start playback for $downloadId: $e',
            ),
      );
      rethrow;
    } finally {
      if (ref.read(playbackLoadingIdProvider) == downloadId) {
        ref.read(playbackLoadingIdProvider.notifier).state = null;
      }
    }
  }

  /// PLAN.md Phase 6.8: play an on-device file that never came from the
  /// server. No network involved at all — not even a cellular check, since
  /// there's nothing to fetch.
  Future<void> playLocalMedia(String id) async {
    ref.read(playbackLoadingIdProvider.notifier).state = id;
    _resetPlaybackHealth();
    try {
      final item = await ref
          .read(localMediaRepositoryProvider)
          .buildPlayableItem(id);
      if (item == null || item.tracks.isEmpty) return;
      final sourceUri = Uri.file(item.tracks.first.contentUrl);

      ref.read(currentPlaybackItemProvider.notifier).state = item;
      await _handler.loadItem(
        item: item,
        sourceUris: [sourceUri],
        startPosition: item.progress?.currentTime ?? 0,
      );
      _handler.onItemFinished = () => _onFinished(item);
      _handler.onPlayerError = (e) => _onPlayerError(item, e);
      // Not awaited: `AudioPlayer.play()`'s Future only completes once
      // playback pauses/stops/completes (see just_audio's doc comment) — the
      // `player.playing` flag it sets flips synchronously, well before that,
      // which is what `playbackState`'s listener above and
      // [playbackLoadingIdProvider]'s consumers actually care about.
      // Awaiting it here would keep this whole method (and the loading
      // indicator tied to it) pending for the entire playback session.
      unawaited(_handler.play());
      _startSyncTimer(item);
    } catch (e) {
      unawaited(
        ref
            .read(logRepositoryProvider)
            .log('error', 'playback', 'Failed to start playback for $id: $e'),
      );
      rethrow;
    } finally {
      if (ref.read(playbackLoadingIdProvider) == id) {
        ref.read(playbackLoadingIdProvider.notifier).state = null;
      }
    }
  }

  /// PLAN.md Phase 9.3 (Data/cellular controls). Only gates *streaming* —
  /// downloaded/offline playback never touches the network regardless.
  Future<bool> _blockedByCellularSetting() async {
    final settings =
        ref.read(appSettingsProvider).valueOrNull ?? const AppSettings();
    if (settings.allowCellularStreaming) return false;
    final onCellular = await isOnCellularConnection(
      ref.read(connectivityProvider),
    );
    if (!onCellular) return false;
    ref.read(cellularBlockNoticeProvider.notifier).state =
        'Streaming over cellular is off in Settings → Data.';
    return true;
  }

  /// Bug fix 2026-08-05 (evan: streamed playback resumed ~15 minutes behind
  /// after the app died mid-outage). `fetchItemDetail`'s `progress` only
  /// reflects what the server has actually received — a periodic sync that
  /// fails while offline is durably queued (see [PendingSyncRepository],
  /// PLAN.md Phase 6.7) so it survives a restart, but nothing previously
  /// consulted that queue when picking a *new* session's start position, so
  /// unflushed local progress was silently discarded in favor of the
  /// server's older number. Takes whichever position is later rather than
  /// always preferring the local queue — another device may have advanced
  /// the server's copy further than anything queued here ever recorded.
  Future<double> _resolveStartPosition(LibraryItemDetail item) async {
    final serverPosition = item.progress?.currentTime ?? 0;
    final pending = await ref
        .read(pendingSyncRepositoryProvider)
        .find(item.id, item.episodeId);
    if (pending == null || pending.currentTime <= serverPosition) {
      return serverPosition;
    }
    return pending.currentTime;
  }

  void _startSyncTimer(LibraryItemDetail item) {
    _syncTimer?.cancel();
    _lastSyncedPosition = null;
    _staleSyncTicks = 0;
    _syncTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _periodicSync(item),
    );
  }

  /// Clears the error/backoff budgets that [_startSyncTimer] deliberately no
  /// longer touches — see [_playerErrorRetryCount]. Called only where a fresh
  /// start is genuinely implied: loading a new item, or the user explicitly
  /// pressing play again after a stream gave up.
  void _resetPlaybackHealth() {
    _playerErrorRetryCount = 0;
    _healthyTicksSinceError = 0;
    _consecutiveSyncFailures = 0;
    _syncBackoffTicks = 0;
    _lastSyncErrorKind = null;
  }

  /// Shared by [playItem]/[playEpisode]'s initial load and
  /// [_recoverFromPlayerError]'s retry — always reads the session fresh
  /// rather than closing over a token, so a retry after
  /// [SessionController.updateTokens] has run picks up the corrected token
  /// automatically instead of repeating the same stale one.
  List<Uri> _streamSourceUris(
    List<AudioTrack> tracks,
    SessionAuthenticated session,
  ) {
    return tracks
        .map(
          (t) => Uri.parse(
            audioStreamUrl(
              serverUrl: session.serverUrl,
              relativeContentUrl: t.contentUrl,
              token: session.user.effectiveToken,
            ),
          ),
        )
        .toList();
  }

  /// Debugging note (2026-08-03, investigating a "stuck playing" report):
  /// `playbackState.playing` never auto-flips to false on a `just_audio`
  /// player error (see [SteepedAudioHandler]'s `errorStream` note) — so if
  /// the underlying stream stalls (e.g. a stale/expired token after a long
  /// idle period, or a dropped connection) with no error surfaced at all,
  /// this timer would otherwise keep ticking and re-syncing the same frozen
  /// position forever with zero visible signal. This wraps the ordinary
  /// [_sync] call with a watchdog: only the periodic (still-marked-playing)
  /// tick feeds the counter — the one-off sync triggered by a genuine pause
  /// in [_onPlaybackStateChanged] does not, so a deliberate pause is never
  /// mistaken for a stall.
  Future<void> _periodicSync(LibraryItemDetail item) async {
    final position = _handler.globalPositionSeconds;
    if (_lastSyncedPosition != null &&
        (position - _lastSyncedPosition!).abs() < 0.5) {
      _staleSyncTicks++;
      _healthyTicksSinceError = 0;
      if (_staleSyncTicks == 2) {
        unawaited(
          ref
              .read(logRepositoryProvider)
              .log(
                'warning',
                'playback',
                'Position frozen at ${position.toStringAsFixed(1)}s for '
                    '${item.id} across 2 sync ticks (~30s) while '
                    'playing=true — possible stuck stream (stale token or '
                    'dropped connection).',
              ),
        );
      }
    } else {
      _staleSyncTicks = 0;
      // The stream is genuinely delivering audio. Once it has done so for
      // ~1 minute straight, whatever error we last recovered from is behind
      // us and [_recoverFromPlayerError] may have its full budget back — see
      // [_playerErrorRetryCount] for why that can't just happen on reload.
      if (_playerErrorRetryCount > 0 && ++_healthyTicksSinceError >= 4) {
        _playerErrorRetryCount = 0;
        _healthyTicksSinceError = 0;
      }
    }
    _lastSyncedPosition = position;

    // Two reasons to skip the network half of this tick and only refresh the
    // local cache. Either way progress is safe: the cache below is what
    // offline resume reads, and a later tick (or the durable Phase 6.7 queue)
    // still carries the position to the server.
    //
    //  - A previous sync is still in flight. This timer doesn't wait for its
    //    own previous tick, so against a slow server the old code accumulated
    //    concurrent PATCHes, all aimed at the one host the audio stream also
    //    depends on. Dropping the tick is free — the next one carries a newer
    //    position anyway.
    //  - We're backing off after consecutive failures. Re-hammering a server
    //    that is already failing to answer every 15s achieves nothing the
    //    queue doesn't, and adds load exactly when the stream can least
    //    afford it.
    //
    // Deliberately checked here rather than inside [_sync]: the one-shot syncs
    // (pause, finish, close player) are user-driven, rare, and carry the
    // position that actually matters, so they must never be dropped.
    if (!item.isLocalOnly && (_syncInFlight || _syncBackoffTicks > 0)) {
      if (!_syncInFlight) _syncBackoffTicks--;
      await _updateLocalProgressCache(item.downloadId, position, false);
      return;
    }
    await _sync(item);
  }

  /// Logs a `just_audio` player error (see
  /// [SteepedAudioHandler.onPlayerError]) so a silent stream failure shows
  /// up in Settings → Logs instead of leaving no trace at all, then attempts
  /// automatic recovery — see [_recoverFromPlayerError].
  void _onPlayerError(LibraryItemDetail item, PlayerException e) {
    unawaited(
      ref
          .read(logRepositoryProvider)
          .log(
            'error',
            'playback',
            'Player error for ${item.id} (code ${e.code}): ${e.message}',
          ),
    );
    unawaited(_recoverFromPlayerError(item));
  }

  static const _maxPlayerErrorRetries = 3;

  /// Bug fix 2026-08-04 (evan: streamed playback froze *again* after another
  /// idle period — the 2026-08-03 fix only added logging/pause, so the user
  /// still had to notice and manually restart it, and since progress hadn't
  /// actually advanced past the freeze point, reopening the app looked like
  /// it had "reverted"). The 2026-08-03 SessionController.updateTokens fix
  /// closes the *original* trigger (a stale in-memory token surviving a
  /// reactive refresh), but a source error can still happen for other
  /// transient reasons — a brief network blip, a server restart — so this
  /// adds a bounded automatic retry that rebuilds the stream URL(s) with
  /// whatever token is current *right now* and resumes from the last known
  /// position, instead of just giving up on the first failure.
  ///
  /// Only applies to a genuine live stream: retrying a downloaded file or a
  /// local-media import that failed to decode wouldn't fix anything (that's
  /// not a token/network problem), so those still just pause immediately,
  /// same as before this fix.
  ///
  /// Follow-up 2026-08-05 (evan: playback staggering): the retry budget here
  /// is now genuinely bounded — see [_playerErrorRetryCount] — and concurrent
  /// recoveries are collapsed, because `just_audio` emits a burst of errors
  /// for one dropped connection and each used to start its own reload against
  /// the same player. Backoff is also exponential rather than linear: the
  /// underlying condition is usually a server that needs more than four
  /// seconds to come back, and re-preparing the playlist too eagerly is the
  /// thing the listener actually hears.
  Future<void> _recoverFromPlayerError(LibraryItemDetail item) async {
    if (_recoveryInFlight) return;
    _recoveryInFlight = true;
    try {
      await _attemptRecovery(item);
    } finally {
      _recoveryInFlight = false;
    }
  }

  Future<void> _attemptRecovery(LibraryItemDetail item) async {
    final current = ref.read(currentPlaybackItemProvider);
    final isStillCurrent =
        current != null && current.downloadId == item.downloadId;
    final session = ref.read(sessionControllerProvider);
    final isDownloaded = await ref
        .read(downloadRepositoryProvider)
        .isDownloaded(item.downloadId);
    final canRetry =
        isStillCurrent &&
        !item.isLocalOnly &&
        !isDownloaded &&
        session is SessionAuthenticated &&
        _playerErrorRetryCount < _maxPlayerErrorRetries;

    if (!canRetry) {
      ref.read(isReconnectingProvider.notifier).state = false;
      unawaited(_handler.pause());
      // Deliberately NOT resetting [_playerErrorRetryCount] here. Giving up
      // is the end of this run; the budget comes back on an explicit user
      // [resume], a new item, or a sustained stretch of healthy playback —
      // never automatically, which is what let the old version loop.
      if (isStillCurrent && _playerErrorRetryCount >= _maxPlayerErrorRetries) {
        unawaited(
          ref
              .read(logRepositoryProvider)
              .log(
                'error',
                'playback',
                'Giving up on ${item.id} after $_maxPlayerErrorRetries failed '
                    'reconnect attempts — paused. Press play to retry.',
              ),
        );
      }
      return;
    }

    ref.read(isReconnectingProvider.notifier).state = true;
    _playerErrorRetryCount++;
    _healthyTicksSinceError = 0;
    final attempt = _playerErrorRetryCount;
    unawaited(
      ref
          .read(logRepositoryProvider)
          .log(
            'warning',
            'playback',
            'Retrying playback for ${item.id} after player error '
                '(attempt $attempt/$_maxPlayerErrorRetries)',
          ),
    );
    // 2s, 6s, 14s — enough for a restarting server or a wifi/cellular handoff
    // to settle, instead of reloading straight back into the same failure.
    await Future.delayed(Duration(seconds: (1 << attempt) * 2 - 2));

    // The user may have moved on (or stopped playback outright) during that
    // delay — re-check rather than yanking a now-unrelated item back in.
    final stillCurrent = ref.read(currentPlaybackItemProvider);
    if (stillCurrent == null || stillCurrent.downloadId != item.downloadId) {
      ref.read(isReconnectingProvider.notifier).state = false;
      return;
    }

    try {
      final resumePosition = _handler.globalPositionSeconds;
      await _handler.loadItem(
        item: item,
        sourceUris: _streamSourceUris(item.tracks, session),
        startPosition: resumePosition,
      );
      _handler.onItemFinished = () => _onFinished(item);
      _handler.onPlayerError = (e) => _onPlayerError(item, e);
      unawaited(_handler.play());
      _startSyncTimer(item);
      ref.read(isReconnectingProvider.notifier).state = false;
    } catch (e) {
      unawaited(
        ref
            .read(logRepositoryProvider)
            .log('error', 'playback', 'Retry failed for ${item.id}: $e'),
      );
      // Recurses through the *inner* method on purpose: the re-entrancy guard
      // in [_recoverFromPlayerError] is still held by this call, and going
      // through it again would silently drop this retry instead of taking the
      // next attempt (or the give-up branch above).
      await _attemptRecovery(item);
    }
  }

  /// Updates the local downloaded-item progress cache (a no-op if this item
  /// was never downloaded) independently of whether the server sync below
  /// succeeds — this is what lets a downloaded item resume correctly even
  /// across multiple fully-offline play sessions, not just the first one.
  Future<void> _updateLocalProgressCache(
    String itemId,
    double currentTime,
    bool isFinished,
  ) {
    return ref
        .read(downloadRepositoryProvider)
        .updateLocalProgress(
          itemId: itemId,
          currentTime: currentTime,
          isFinished: isFinished,
        );
  }

  Future<void> _sync(LibraryItemDetail item) async {
    final currentTime = _handler.globalPositionSeconds;
    if (item.isLocalOnly) {
      await ref
          .read(localMediaRepositoryProvider)
          .updateProgress(item.id, currentTime);
      return;
    }
    await _updateLocalProgressCache(item.downloadId, currentTime, false);

    // Nothing to gain from a DNS lookup and a connect timeout we already know
    // will fail; queue it and move on. This is the `Failed host lookup` case
    // in the log — the phone had genuinely dropped off the network.
    if (!await _hasNetwork()) {
      await _enqueueFailedSync(item, currentTime);
      _noteSyncFailure(item, 'offline');
      return;
    }

    _syncInFlight = true;
    try {
      await ref
          .read(progressRepositoryProvider)
          .updateProgress(
            libraryItemId: item.id,
            episodeId: item.episodeId,
            currentTime: currentTime,
            duration: item.duration ?? 0,
          );
      await _clearPendingSync(item);
      _consecutiveSyncFailures = 0;
      _syncBackoffTicks = 0;
      _lastSyncErrorKind = null;
    } catch (e) {
      // Best-effort in the moment (a dedicated "sync failed" UI is deferred,
      // 5.9 note), but PLAN.md Phase 6.7: also durably queue it so a
      // reconnect *after the app restarts* still uploads it, not just a
      // reconnect within the same still-open session (the old behavior).
      await _enqueueFailedSync(item, currentTime);
      _noteSyncFailure(item, _describeSyncError(e));
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> _enqueueFailedSync(LibraryItemDetail item, double currentTime) {
    return ref
        .read(pendingSyncRepositoryProvider)
        .enqueue(
          libraryItemId: item.id,
          episodeId: item.episodeId,
          currentTime: currentTime,
          duration: item.duration ?? 0,
        );
  }

  /// Retires any queued row for this item once the server has accepted a
  /// newer position directly.
  ///
  /// Without this the queue kept a row from the last *failed* attempt even
  /// after later attempts succeeded, and [PendingSyncController] would
  /// eventually upload that stale position — rewinding the server behind
  /// where the live sync had already put it. Previously masked by the fact
  /// that the flush ran against the playing item too, so the next 15s tick
  /// immediately corrected it; now that the flush correctly leaves the
  /// playing item alone, the stale row has to actually be cleared.
  Future<void> _clearPendingSync(LibraryItemDetail item) {
    return ref
        .read(pendingSyncRepositoryProvider)
        .remove(item.id, item.episodeId);
  }

  Future<bool> _hasNetwork() async {
    try {
      final results = await ref.read(connectivityProvider).checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Never let a connectivity-plugin hiccup be the reason a sync doesn't
      // even get attempted — assume online and let the request decide.
      return true;
    }
  }

  /// A short, stable label per failure *kind* rather than the full exception
  /// text — `DioException`'s message embeds the exact timeout duration and a
  /// paragraph of remediation advice, which is what made every entry in the
  /// log look different enough to keep writing but identical to read.
  String _describeSyncError(Object e) {
    if (e is DioException) {
      return switch (e.type) {
        DioExceptionType.badResponse =>
          'server returned ${e.response?.statusCode}',
        DioExceptionType.cancel => 'timed out (10s deadline)',
        DioExceptionType.connectionError => 'server unreachable',
        _ => e.type.name,
      };
    }
    return e.runtimeType.toString();
  }

  /// Records a failed sync: schedules the exponential backoff and writes at
  /// most one log entry per run of same-kind failures, with a running count,
  /// instead of one per 15s tick.
  void _noteSyncFailure(LibraryItemDetail item, String kind) {
    _consecutiveSyncFailures++;
    // 15s -> 30s -> 60s -> 120s -> 120s..., counted in skipped 15s ticks.
    _syncBackoffTicks = switch (_consecutiveSyncFailures) {
      1 => 1,
      2 => 3,
      _ => 7,
    };

    final isNewKind = kind != _lastSyncErrorKind;
    _lastSyncErrorKind = kind;
    // First failure of a run, a change in cause, and then only every 8th
    // repeat — enough to show an outage is ongoing without flooding the
    // 500-entry cap and evicting every other tag.
    if (!isNewKind && _consecutiveSyncFailures % 8 != 0) return;

    final suffix = _consecutiveSyncFailures > 1
        ? ' (failure #$_consecutiveSyncFailures in a row; progress is queued '
              'locally and will upload when the server responds)'
        : ' (progress queued locally)';
    unawaited(
      ref
          .read(logRepositoryProvider)
          .log(
            'warning',
            'progress-sync',
            'Sync failed for ${item.id}: $kind$suffix',
          ),
    );
  }

  Future<void> _onFinished(LibraryItemDetail item) async {
    _syncTimer?.cancel();
    _syncTimer = null;
    final currentTime = item.duration ?? _handler.globalPositionSeconds;
    if (item.isLocalOnly) {
      await ref
          .read(localMediaRepositoryProvider)
          .updateProgress(item.id, currentTime);
      return;
    }
    await _updateLocalProgressCache(item.downloadId, currentTime, true);
    try {
      await ref
          .read(progressRepositoryProvider)
          .updateProgress(
            libraryItemId: item.id,
            episodeId: item.episodeId,
            currentTime: currentTime,
            duration: item.duration ?? 0,
            isFinished: true,
          );
      await _clearPendingSync(item);
    } catch (_) {
      await ref
          .read(pendingSyncRepositoryProvider)
          .enqueue(
            libraryItemId: item.id,
            episodeId: item.episodeId,
            currentTime: currentTime,
            duration: item.duration ?? 0,
            isFinished: true,
          );
    }
  }

  /// No explicit sync here — the `playbackState` listener above reacts to
  /// the resulting `playing: false` regardless of who paused it.
  Future<void> pause() => _handler.pause();

  /// An explicit user press is the one unambiguous signal that they want us to
  /// try again, so it restores the reconnect/backoff budgets that a failed run
  /// deliberately leaves spent (see [_playerErrorRetryCount]).
  Future<void> resume() {
    _resetPlaybackHealth();
    return _handler.play();
  }

  /// PLAN.md Phase 9.3: jump interval is now configurable in Settings →
  /// Playback (was fixed at 30s per the PLAN.md 5.5 note).
  Future<void> jumpForward() => _handler.jumpBy(_jumpIntervalSeconds.toDouble());

  Future<void> jumpBackward() =>
      _handler.jumpBy(-_jumpIntervalSeconds.toDouble());

  int get _jumpIntervalSeconds =>
      ref.read(appSettingsProvider).valueOrNull?.jumpIntervalSeconds ?? 30;

  Future<void> seekToGlobalPosition(double seconds) =>
      _handler.seekToGlobalPosition(seconds);

  Future<void> setSpeed(double speed) => _handler.setSpeed(speed);

  Future<void> markFinished(bool finished) async {
    final item = ref.read(currentPlaybackItemProvider);
    if (item == null) return;
    final currentTime = finished ? (item.duration ?? 0) : 0.0;
    if (item.isLocalOnly) {
      await ref
          .read(localMediaRepositoryProvider)
          .updateProgress(item.id, currentTime);
      return;
    }
    await _updateLocalProgressCache(item.downloadId, currentTime, finished);
    try {
      await ref
          .read(progressRepositoryProvider)
          .updateProgress(
            libraryItemId: item.id,
            episodeId: item.episodeId,
            currentTime: currentTime,
            duration: item.duration ?? 0,
            isFinished: finished,
          );
      await _clearPendingSync(item);
    } catch (_) {
      await ref
          .read(pendingSyncRepositoryProvider)
          .enqueue(
            libraryItemId: item.id,
            episodeId: item.episodeId,
            currentTime: currentTime,
            duration: item.duration ?? 0,
            isFinished: finished,
          );
    }
  }

  Future<void> closePlayer() async {
    final item = ref.read(currentPlaybackItemProvider);
    _syncTimer?.cancel();
    _syncTimer = null;
    if (item != null) await _sync(item);
    // Clear before stopping: `stop()` resets the player's position, and if
    // the playbackState listener above saw the item still set, it would
    // fire a second, wrong sync at position 0 right after the correct one.
    ref.read(currentPlaybackItemProvider.notifier).state = null;
    await _handler.stop();
  }
}

final playbackControllerProvider = NotifierProvider<PlaybackController, void>(
  PlaybackController.new,
);
