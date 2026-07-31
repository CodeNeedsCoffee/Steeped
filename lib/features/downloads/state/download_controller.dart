import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/podcast_episode.dart';
import '../data/download_repository.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(ref.watch(appDatabaseProvider));
});

/// Drives the Downloads screen.
final downloadsListProvider = StreamProvider<List<DownloadedItem>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchDownloads();
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
        }
      case TaskProgressUpdate():
        final itemId = update.task.metaData;
        if (itemId.isEmpty) return;
        final map = {...ref.read(downloadProgressProvider)};
        map[itemId] = update.progress;
        ref.read(downloadProgressProvider.notifier).state = map;
    }
  }

  Future<void> download({
    required LibraryItemDetail item,
    required String serverUrl,
    required String? token,
  }) {
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
  }) {
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
}

final downloadControllerProvider = NotifierProvider<DownloadController, void>(
  DownloadController.new,
);
