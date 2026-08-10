import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/log_repository.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/app_database.dart';
import '../data/pending_sync_repository.dart';
import 'playback_controller.dart';

final pendingSyncRepositoryProvider = Provider<PendingSyncRepository>((ref) {
  return PendingSyncRepository(ref.watch(appDatabaseProvider));
});

/// Count of not-yet-uploaded progress syncs — available for a future "N
/// pending" indicator; not currently surfaced in the UI.
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(pendingSyncRepositoryProvider).watchPendingCount();
});

/// PLAN.md Phase 6.7: flushes the durable pending-sync queue on app start,
/// whenever connectivity is regained, and on a periodic timer. Must be
/// watched once near app root (see [HomeShellScreen], same pattern as
/// `DownloadController`) to activate the connectivity listener.
class PendingSyncController extends Notifier<void> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _periodicTimer;
  Timer? _connectivityDebounce;

  /// Bug fix 2026-08-05 (evan: playback staggering). [flushPending] had no
  /// re-entrancy guard, and Android emits a *burst* of connectivity events
  /// during a single wifi/cellular handoff (interface down, then up, then
  /// validated) — so one handoff kicked off several concurrent full passes
  /// over the queue, each PATCHing the same rows, on top of whatever the
  /// 3-minute timer and the app-start call were already doing. Every one of
  /// those requests competes with the audio stream for the same server. One
  /// flush at a time is all that was ever wanted.
  bool _flushing = false;

  @override
  void build() {
    _sub = ref
        .read(connectivityProvider)
        .onConnectivityChanged
        .listen((results) {
          if (results.any((r) => r != ConnectivityResult.none)) {
            // Collapse the burst: a handoff settles well inside 2s, and the
            // queue is not so urgent that it can't wait for the network to
            // stop moving underneath it.
            _connectivityDebounce?.cancel();
            _connectivityDebounce = Timer(
              const Duration(seconds: 2),
              flushPending,
            );
          }
        });
    // Bug found 2026-08-02 (reported by evan as "weird errors" in the
    // Logs screen): `onConnectivityChanged` only fires when the network
    // *type* changes (e.g. wifi -> cellular) — it never fires for a DNS
    // hiccup or a slow/unresponsive server while the same network stays
    // up the whole time, which is exactly what "receive timeout" and
    // intermittent "Failed host lookup" log entries mean. A queued sync
    // that failed for one of those reasons had no trigger to ever retry
    // it again short of the next full app restart — confirmed live: a
    // sync stuck since 10:59am that morning only cleared once the app was
    // force-stopped and relaunched, despite the network being fine the
    // whole time in between. This timer is the fix: retry periodically
    // regardless of whether connectivity ever "changed".
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => flushPending(),
    );
    ref.onDispose(() {
      _sub?.cancel();
      _periodicTimer?.cancel();
      _connectivityDebounce?.cancel();
    });
    // Also try immediately: connectivity may already have been restored
    // while the app was closed, so don't wait for the next change event.
    flushPending();
  }

  Future<void> flushPending() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _flush();
    } finally {
      _flushing = false;
    }
  }

  Future<void> _flush() async {
    final repo = ref.read(pendingSyncRepositoryProvider);
    final progressRepo = ref.read(progressRepositoryProvider);
    // The item currently playing is owned by [PlaybackController]'s own 15s
    // sync, which holds a strictly fresher position than anything sitting in
    // this queue. Uploading the queued row would at best duplicate that work
    // and at worst land *after* it, overwriting the live position with a
    // stale one — PLAN.md Phase 6.7's queue is for progress with nothing else
    // looking after it. The live sync clears its own row on success.
    final playing = ref.read(currentPlaybackItemProvider);

    for (final row in await repo.pending()) {
      if (playing != null &&
          playing.id == row.libraryItemId &&
          playing.episodeId == row.episodeId) {
        continue;
      }
      try {
        await progressRepo.updateProgress(
          libraryItemId: row.libraryItemId,
          episodeId: row.episodeId,
          currentTime: row.currentTime,
          duration: row.duration,
          isFinished: row.isFinished,
        );
        await repo.remove(row.libraryItemId, row.episodeId);
      } on DioException catch (e) {
        if (e.type != DioExceptionType.badResponse) {
          // Still offline/unreachable — leave the whole queue queued and
          // stop; the next connectivity change or app start tries again.
          return;
        }
        // A real server response (e.g. 404 — item no longer exists)
        // means retrying will never succeed; drop it rather than
        // blocking every other queued sync forever.
        await repo.remove(row.libraryItemId, row.episodeId);
        unawaited(
          ref
              .read(logRepositoryProvider)
              .log(
                'warning',
                'progress-sync',
                'Dropped queued sync for ${row.libraryItemId}: server '
                    'rejected it (${e.response?.statusCode})',
              ),
        );
      }
    }
  }
}

final pendingSyncControllerProvider =
    NotifierProvider<PendingSyncController, void>(PendingSyncController.new);
