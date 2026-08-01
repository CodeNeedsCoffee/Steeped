import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/log_repository.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/device_storage.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/podcast_episode.dart';
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
  @override
  void build() {
    FileDownloader().updates.listen(_onUpdate);
  }

  void _onUpdate(TaskUpdate update) {
    switch (update) {
      case TaskStatusUpdate():
        if (update.status == TaskStatus.complete) {
          final repo = ref.read(downloadRepositoryProvider);
          if (update.task.taskId.endsWith('__cover')) {
            repo.onCoverComplete(update.task);
          } else {
            repo.onTrackComplete(update.task);
          }
        } else if (update.status == TaskStatus.failed) {
          ref
              .read(logRepositoryProvider)
              .log(
                'error',
                'download',
                'Download failed for task ${update.task.taskId}: '
                    '${update.exception}',
              );
        }
      case TaskProgressUpdate():
        final itemId = update.task.metaData;
        if (itemId.isEmpty) return;
        final map = {...ref.read(downloadProgressProvider)};
        map[itemId] = update.progress;
        ref.read(downloadProgressProvider.notifier).state = map;
    }
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
