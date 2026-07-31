import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_handler_provider.dart';
import '../../../core/audio/steeped_audio_handler.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/library_item_detail.dart';
import '../../auth/state/session_controller.dart';
import '../../auth/state/session_state.dart';
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

  Future<void> playItem(String itemId) async {
    final session = ref.read(sessionControllerProvider);
    if (session is! SessionAuthenticated) return;

    final item = await ref
        .read(libraryRepositoryProvider)
        .fetchItemDetail(itemId);
    if (item.isPodcast || item.tracks.isEmpty) return;

    ref.read(currentPlaybackItemProvider.notifier).state = item;
    await _handler.loadItem(
      item: item,
      serverUrl: session.serverUrl,
      token: session.user.effectiveToken,
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
