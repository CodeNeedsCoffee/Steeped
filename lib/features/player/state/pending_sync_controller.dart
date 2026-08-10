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

/// PLAN.md Phase 6.7: flushes the durable pending-sync queue on app start
/// and whenever connectivity is regained. Must be watched once near app
/// root (see [HomeShellScreen], same pattern as `DownloadController`) to
/// activate the connectivity listener.
class PendingSyncController extends Notifier<void> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void build() {
    _sub = ref
        .read(connectivityProvider)
        .onConnectivityChanged
        .listen((results) {
          if (results.any((r) => r != ConnectivityResult.none)) {
            flushPending();
          }
        });
    ref.onDispose(() => _sub?.cancel());
    // Also try immediately: connectivity may already have been restored
    // while the app was closed, so don't wait for the next change event.
    flushPending();
  }

  Future<void> flushPending() async {
    final repo = ref.read(pendingSyncRepositoryProvider);
    final progressRepo = ref.read(progressRepositoryProvider);
    for (final row in await repo.pending()) {
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
