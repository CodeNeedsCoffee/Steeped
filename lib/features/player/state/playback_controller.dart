import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_handler_provider.dart';
import '../../../core/audio/steeped_audio_handler.dart';
import '../../../core/network/audio_stream_url.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/podcast_episode.dart';
import '../../auth/state/session_controller.dart';
import '../../auth/state/session_state.dart';
import '../../downloads/state/download_controller.dart';
import '../../library/state/library_providers.dart';
import '../data/progress_repository.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(dioProvider));
});

/// The item currently loaded into the player, or null if nothing is
/// playing — drives whether the mini-player shows at all.
final currentPlaybackItemProvider = StateProvider<LibraryItemDetail?>(
  (ref) => null,
);

final playbackPositionProvider = StreamProvider<double>((ref) {
  return ref.watch(audioHandlerProvider).globalPositionStream;
});

final isPlayingProvider = StreamProvider<bool>((ref) {
  return ref.watch(audioHandlerProvider).playbackState.map((s) => s.playing);
});

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
  StreamSubscription<PlaybackState>? _playbackStateSub;
  bool _wasPlaying = false;

  @override
  void build() {
    _playbackStateSub = _handler.playbackState.listen(_onPlaybackStateChanged);
    ref.onDispose(() {
      _syncTimer?.cancel();
      _playbackStateSub?.cancel();
    });
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
      final fetched = await ref
          .read(libraryRepositoryProvider)
          .fetchItemDetail(itemId);
      if (fetched.isPodcast || fetched.tracks.isEmpty) return;
      item = fetched;
      sourceUris = fetched.tracks
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

    ref.read(currentPlaybackItemProvider.notifier).state = item;
    await _handler.loadItem(
      item: item,
      sourceUris: sourceUris,
      startPosition: item.progress?.currentTime ?? 0,
    );
    _handler.onItemFinished = () => _onFinished(item);
    await _handler.play();
    _startSyncTimer(item);
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
    final downloadRepo = ref.read(downloadRepositoryProvider);
    if (await downloadRepo.isDownloaded(downloadId)) {
      await playItem(downloadId);
      return;
    }

    final session = ref.read(sessionControllerProvider);
    if (session is! SessionAuthenticated) return;
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

    final sourceUri = Uri.parse(
      audioStreamUrl(
        serverUrl: session.serverUrl,
        relativeContentUrl: track.contentUrl,
        token: session.user.effectiveToken,
      ),
    );

    ref.read(currentPlaybackItemProvider.notifier).state = item;
    await _handler.loadItem(
      item: item,
      sourceUris: [sourceUri],
      startPosition: item.progress?.currentTime ?? 0,
    );
    _handler.onItemFinished = () => _onFinished(item);
    await _handler.play();
    _startSyncTimer(item);
  }

  void _startSyncTimer(LibraryItemDetail item) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sync(item),
    );
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
    await _updateLocalProgressCache(item.downloadId, currentTime, false);
    try {
      await ref
          .read(progressRepositoryProvider)
          .updateProgress(
            libraryItemId: item.id,
            episodeId: item.episodeId,
            currentTime: currentTime,
            duration: item.duration ?? 0,
          );
    } catch (_) {
      // Best-effort — a dedicated "sync failed" UI is deferred (5.9 note).
    }
  }

  Future<void> _onFinished(LibraryItemDetail item) async {
    _syncTimer?.cancel();
    final currentTime = item.duration ?? _handler.globalPositionSeconds;
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
    } catch (_) {}
  }

  /// No explicit sync here — the `playbackState` listener above reacts to
  /// the resulting `playing: false` regardless of who paused it.
  Future<void> pause() => _handler.pause();

  Future<void> resume() => _handler.play();

  Future<void> jumpForward() => _handler.jumpBy(30);

  Future<void> jumpBackward() => _handler.jumpBy(-30);

  Future<void> seekToGlobalPosition(double seconds) =>
      _handler.seekToGlobalPosition(seconds);

  Future<void> setSpeed(double speed) => _handler.setSpeed(speed);

  Future<void> markFinished(bool finished) async {
    final item = ref.read(currentPlaybackItemProvider);
    if (item == null) return;
    final currentTime = finished ? (item.duration ?? 0) : 0.0;
    await _updateLocalProgressCache(item.downloadId, currentTime, finished);
    await ref
        .read(progressRepositoryProvider)
        .updateProgress(
          libraryItemId: item.id,
          episodeId: item.episodeId,
          currentTime: currentTime,
          duration: item.duration ?? 0,
          isFinished: finished,
        );
  }

  Future<void> closePlayer() async {
    final item = ref.read(currentPlaybackItemProvider);
    _syncTimer?.cancel();
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
