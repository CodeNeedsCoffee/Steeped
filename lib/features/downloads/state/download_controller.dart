import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/log_repository.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/device_storage.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/podcast_episode.dart';
import '../../auth/data/token_refresh_coordinator.dart';
import '../../auth/state/session_controller.dart';
import '../../auth/state/session_state.dart';
import '../../library/state/library_providers.dart';
import '../../settings/data/app_settings.dart';
import '../../settings/state/settings_providers.dart';
import '../data/download_repository.dart';

/// Below this much free device space, the Downloads screen shows a
/// low-storage warning (PLAN.md Phase 6.10).
const lowStorageThresholdBytes = 500 * 1024 * 1024;

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(ref.watch(appDatabaseProvider));
});

/// Drives the Downloads screen.
final downloadsListProvider = StreamProvider<List<DownloadedItem>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchDownloads();
});

/// PLAN.md Phase 6.10: on-disk size of one downloaded item.
final downloadItemSizeProvider = FutureProvider.family<int, String>((
  ref,
  itemId,
) {
  return ref.watch(downloadRepositoryProvider).sizeOfItem(itemId);
});

/// PLAN.md Phase 6.10: total space used by all downloads, recomputed
/// whenever the downloads list changes.
final downloadsTotalSizeProvider = FutureProvider<int>((ref) async {
  final downloads = await ref.watch(downloadsListProvider.future);
  final repo = ref.watch(downloadRepositoryProvider);
  var total = 0;
  for (final item in downloads) {
    total += await repo.sizeOfItem(item.itemId);
  }
  return total;
});

/// PLAN.md Phase 6.10: free device storage, recomputed alongside the
/// downloads list so it reflects space just freed/used. Null means unknown
/// (e.g. iOS, where [DeviceStorage] isn't implemented yet) — the UI simply
/// skips the low-storage banner in that case rather than guessing.
final deviceFreeSpaceProvider = FutureProvider<int?>((ref) async {
  ref.watch(downloadsListProvider);
  return DeviceStorage.freeBytes();
});

/// Most recent progress (0..1) per item id — enough for a progress bar,
/// not a full per-track breakdown.
final downloadProgressProvider = StateProvider<Map<String, double>>(
  (ref) => {},
);

/// PLAN.md Phase 6.1: listens to `FileDownloader().updates` globally (must
/// be watched somewhere near app root to activate — see [HomeShellScreen])
/// and writes completed tracks/covers into drift via [DownloadRepository].
class DownloadController extends Notifier<void> {
  /// Bounds [_retryWithFreshToken] per task id — see that method's doc
  /// comment. Cleared on success so a task that later fails again (a fresh
  /// download queued much later, reusing the same `downloadId`/track index
  /// and therefore the same task id) gets its own full budget rather than
  /// inheriting a count from an unrelated earlier attempt.
  final Map<String, int> _authRetryCounts = {};
  static const _maxAuthRetries = 2;

  @override
  void build() {
    FileDownloader().updates.listen(_onUpdate);
  }

  void _onUpdate(TaskUpdate update) {
    switch (update) {
      case TaskStatusUpdate():
        if (update.status == TaskStatus.complete) {
          _authRetryCounts.remove(update.task.taskId);
          final repo = ref.read(downloadRepositoryProvider);
          if (update.task.taskId.endsWith('__cover')) {
            repo.onCoverComplete(update.task);
          } else {
            repo.onTrackComplete(update.task);
          }
        } else if (update.status == TaskStatus.failed) {
          if (_isAuthFailure(update)) {
            unawaited(_retryWithFreshToken(update.task));
          } else {
            ref
                .read(logRepositoryProvider)
                .log(
                  'error',
                  'download',
                  'Download failed for task ${update.task.taskId}: '
                      '${update.exception}',
                );
          }
        }
      case TaskProgressUpdate():
        final itemId = update.task.metaData;
        if (itemId.isEmpty) return;
        final map = {...ref.read(downloadProgressProvider)};
        map[itemId] = update.progress;
        ref.read(downloadProgressProvider.notifier).state = map;
    }
  }

  bool _isAuthFailure(TaskStatusUpdate update) {
    final exception = update.exception;
    final code = update.responseStatusCode ??
        (exception is TaskHttpException ? exception.httpResponseCode : null);
    return code == 401 || code == 403;
  }

  /// Bug fix 2026-09-22 (evan: downloads of long books occasionally missing
  /// tracks). Each track/cover [DownloadTask.url] has the access token baked
  /// in at enqueue time (see [DownloadRepository._enqueue]) — the same
  /// short-lived JWT whose mid-book expiry [PlaybackController
  /// ._attemptRecovery] already guards against for live streaming. A large
  /// download queued over a slow connection can easily outlive that token,
  /// and unlike a stream, `background_downloader`'s own built-in retry (see
  /// its `retries` task option, unused here) just resubmits the identical,
  /// still-expired URL — it has no way to know the URL itself needs
  /// rebuilding. This forces a refresh through the same
  /// [TokenRefreshCoordinator] used everywhere else, then re-enqueues the
  /// exact same task with a fresh token spliced into its URL. Bounded to
  /// [_maxAuthRetries] per task id so a genuinely revoked session (or a
  /// legacy pre-2.26.0 server with no refresh endpoint at all) fails once
  /// and stops instead of looping forever.
  Future<void> _retryWithFreshToken(Task task) async {
    final attempts = (_authRetryCounts[task.taskId] ?? 0) + 1;
    if (attempts > _maxAuthRetries) {
      unawaited(
        ref
            .read(logRepositoryProvider)
            .log(
              'error',
              'download',
              'Giving up on ${task.taskId} after $_maxAuthRetries '
                  'auth-refresh retries',
            ),
      );
      return;
    }
    _authRetryCounts[task.taskId] = attempts;

    final session = ref.read(sessionControllerProvider);
    if (session is! SessionAuthenticated) return;

    final String? freshToken;
    try {
      final user = await ref
          .read(tokenRefreshCoordinatorProvider)
          .refresh(serverUrl: session.serverUrl);
      // Same reasoning as PlaybackController._refreshSessionToken: push the
      // refreshed tokens into the in-memory session too, not just storage,
      // so a next track that was still mid-download with the old token
      // benefits from the same refresh instead of failing independently.
      ref
          .read(sessionControllerProvider.notifier)
          .updateTokens(
            accessToken: user.accessToken,
            refreshToken: user.refreshToken,
          );
      freshToken = user.effectiveToken;
    } catch (e) {
      unawaited(
        ref
            .read(logRepositoryProvider)
            .log(
              'error',
              'download',
              'Token refresh failed while retrying ${task.taskId}: $e',
            ),
      );
      return;
    }
    if (freshToken == null || task is! DownloadTask) return;

    final uri = Uri.parse(task.url);
    final refreshedUrl = uri
        .replace(queryParameters: {...uri.queryParameters, 'token': freshToken})
        .toString();
    await FileDownloader().enqueue(task.copyWith(url: refreshedUrl));
  }

  /// PLAN.md Phase 9.3 (Data/cellular controls).
  Future<bool> _blockedByCellularSetting() async {
    final settings =
        ref.read(appSettingsProvider).valueOrNull ?? const AppSettings();
    if (settings.allowCellularDownloads) return false;
    final onCellular = await isOnCellularConnection(
      ref.read(connectivityProvider),
    );
    if (!onCellular) return false;
    ref.read(cellularBlockNoticeProvider.notifier).state =
        'Downloading over cellular is off in Settings → Data.';
    return true;
  }

  Future<void> download({
    required LibraryItemDetail item,
    required String serverUrl,
    required String? token,
  }) async {
    if (await _blockedByCellularSetting()) return;
    return ref
        .read(downloadRepositoryProvider)
        .startDownload(item: item, serverUrl: serverUrl, token: token);
  }

  /// PLAN.md Phase 6.2: download every book in [seriesId] not already
  /// downloaded. Skips full series-browse UI (4.5, still deferred) — series
  /// membership comes straight from the existing items-filter endpoint that
  /// 4.4's library grid already uses, just with a `filter=series.<id>` query
  /// param instead of none. Returns how many new downloads were queued, for
  /// the caller to report back to the user.
  Future<int> downloadSeries({
    required String libraryId,
    required String seriesId,
    required String serverUrl,
    required String? token,
  }) async {
    if (await _blockedByCellularSetting()) return 0;
    final items = await ref
        .read(libraryRepositoryProvider)
        .fetchItemsInSeries(libraryId, seriesId);
    final repo = ref.read(downloadRepositoryProvider);
    var queued = 0;
    for (final item in items) {
      if (item.mediaType != 'book') continue;
      if (await repo.isDownloaded(item.id)) continue;
      final detail = await ref
          .read(libraryRepositoryProvider)
          .fetchItemDetail(item.id);
      if (detail.tracks.isEmpty) continue;
      await repo.startDownload(
        item: detail,
        serverUrl: serverUrl,
        token: token,
      );
      queued++;
    }
    return queued;
  }

  /// PLAN.md Phase 7.5: download one podcast episode to the device.
  Future<void> downloadEpisode({
    required LibraryItemDetail podcast,
    required PodcastEpisode episode,
    required String serverUrl,
    required String? token,
  }) async {
    if (await _blockedByCellularSetting()) return;
    return ref
        .read(downloadRepositoryProvider)
        .startEpisodeDownload(
          podcast: podcast,
          episode: episode,
          serverUrl: serverUrl,
          token: token,
        );
  }

  Future<void> delete(String itemId) {
    return ref.read(downloadRepositoryProvider).deleteDownload(itemId);
  }

  /// PLAN.md Phase 6.10: bulk-delete every downloaded item.
  Future<void> deleteAll() {
    return ref.read(downloadRepositoryProvider).deleteAllDownloads();
  }
}

final downloadControllerProvider = NotifierProvider<DownloadController, void>(
  DownloadController.new,
);
