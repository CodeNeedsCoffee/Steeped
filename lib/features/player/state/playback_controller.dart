import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_handler_provider.dart';
import '../../../core/audio/steeped_audio_handler.dart';
import '../../../core/network/audio_stream_url.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/library_item_detail.dart';
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
/// not core to proving playback works) plus on pause/finish/close.
class PlaybackController extends Notifier<void> {
  Timer? _syncTimer;

  @override
  void build() {
    ref.onDispose(() => _syncTimer?.cancel());
  }

  SteepedAudioHandler get _handler => ref.read(audioHandlerProvider);

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

  void _startSyncTimer(LibraryItemDetail item) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sync(item),
    );
  }

  Future<void> _sync(LibraryItemDetail item) async {
    try {
      await ref
          .read(progressRepositoryProvider)
          .updateProgress(
            libraryItemId: item.id,
            currentTime: _handler.globalPositionSeconds,
            duration: item.duration ?? 0,
          );
    } catch (_) {
      // Best-effort — a dedicated "sync failed" UI is deferred (5.9 note).
    }
  }

  Future<void> _onFinished(LibraryItemDetail item) async {
    _syncTimer?.cancel();
    try {
      await ref
          .read(progressRepositoryProvider)
          .updateProgress(
            libraryItemId: item.id,
            currentTime: item.duration ?? _handler.globalPositionSeconds,
            duration: item.duration ?? 0,
            isFinished: true,
          );
    } catch (_) {}
  }

  Future<void> pause() async {
    final item = ref.read(currentPlaybackItemProvider);
    await _handler.pause();
    if (item != null) await _sync(item);
  }

  Future<void> resume() => _handler.play();

  Future<void> jumpForward() => _handler.jumpBy(30);

  Future<void> jumpBackward() => _handler.jumpBy(-30);

  Future<void> seekToGlobalPosition(double seconds) =>
      _handler.seekToGlobalPosition(seconds);

  Future<void> setSpeed(double speed) => _handler.setSpeed(speed);

  Future<void> markFinished(bool finished) async {
    final item = ref.read(currentPlaybackItemProvider);
    if (item == null) return;
    await ref
        .read(progressRepositoryProvider)
        .updateProgress(
          libraryItemId: item.id,
          currentTime: finished ? (item.duration ?? 0) : 0,
          duration: item.duration ?? 0,
          isFinished: finished,
        );
  }

  Future<void> closePlayer() async {
    final item = ref.read(currentPlaybackItemProvider);
    _syncTimer?.cancel();
    if (item != null) await _sync(item);
    await _handler.stop();
    ref.read(currentPlaybackItemProvider.notifier).state = null;
  }
}

final playbackControllerProvider = NotifierProvider<PlaybackController, void>(
  PlaybackController.new,
);
