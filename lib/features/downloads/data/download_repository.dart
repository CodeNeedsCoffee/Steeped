import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/audio_stream_url.dart';
import '../../../core/network/cover_image_url.dart';
import '../../../core/storage/app_database.dart';
import '../../../models/audio_track.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/media_progress.dart';
import '../../../models/podcast_episode.dart';

/// PLAN.md Phase 6.1/6.4/6.6: downloads server items for offline playback.
/// [buildOfflineItemDetail] reconstructs a fully playable item from local
/// drift rows alone — no network call — which is what makes offline
/// playback genuinely work with zero connectivity, not just "play from
/// cache while still checking the server."
class DownloadRepository {
  DownloadRepository(this._db);

  final AppDatabase _db;

  static String groupFor(String downloadId) => 'download-$downloadId';
  // The downloadId can be a composite `podcastId::episodeId` for episodes
  // (PLAN.md Phase 7.5); ':' is fine on ext4/APFS at the POSIX layer but is a
  // path-separator surrogate in some Apple layers, so keep it out of the dir.
  static String _dirFor(String downloadId) =>
      'steeped_downloads/${downloadId.replaceAll(':', '_')}';

  /// Encoded when a downloaded row represents a single podcast episode — see
  /// [LibraryItemDetail.downloadId]. Returns `(podcastId, episodeId)` or null.
  static (String, String)? _episodeIdsFromDownloadId(String downloadId) {
    final sep = downloadId.indexOf('::');
    if (sep == -1) return null;
    return (downloadId.substring(0, sep), downloadId.substring(sep + 2));
  }

  Future<void> startDownload({
    required LibraryItemDetail item,
    required String serverUrl,
    required String? token,
  }) {
    return _enqueue(
      downloadId: item.downloadId,
      coverItemId: item.id,
      updatedAt: item.updatedAt,
      title: item.title,
      authorNames: item.authorNames,
      totalDuration: item.duration,
      chapters: item.chapters,
      tracks: item.tracks,
      progressCurrentTime: item.progress?.currentTime,
      progressIsFinished: item.progress?.isFinished ?? false,
      serverUrl: serverUrl,
      token: token,
    );
  }

  /// PLAN.md Phase 7.5: download a single podcast episode to the device,
  /// reusing the same background_downloader engine as books. Stored under the
  /// composite [LibraryItemDetail.downloadId] so episodes of one podcast don't
  /// collide, with the cover fetched from the parent podcast's item id.
  Future<void> startEpisodeDownload({
    required LibraryItemDetail podcast,
    required PodcastEpisode episode,
    required String serverUrl,
    required String? token,
  }) async {
    final track = episode.audioTrack;
    if (track == null) return;
    await _enqueue(
      downloadId: '${podcast.id}::${episode.id}',
      coverItemId: podcast.id,
      updatedAt: podcast.updatedAt,
      title: episode.title,
      authorNames: podcast.authorNames,
      totalDuration: episode.duration ?? track.duration,
      chapters: const [],
      tracks: [track],
      progressCurrentTime: episode.progress?.currentTime,
      progressIsFinished: episode.progress?.isFinished ?? false,
      serverUrl: serverUrl,
      token: token,
    );
  }

  Future<void> _enqueue({
    required String downloadId,
    required String coverItemId,
    required int updatedAt,
    required String title,
    required String authorNames,
    required double? totalDuration,
    required List<BookChapter> chapters,
    required List<AudioTrack> tracks,
    required double? progressCurrentTime,
    required bool progressIsFinished,
    required String serverUrl,
    required String? token,
  }) async {
    final chaptersJson = jsonEncode(
      chapters
          .map((c) => {'title': c.title, 'start': c.start, 'end': c.end})
          .toList(),
    );

    await _db
        .into(_db.downloadedItems)
        .insertOnConflictUpdate(
          DownloadedItemsCompanion.insert(
            itemId: downloadId,
            serverUrl: serverUrl,
            title: title,
            authorNames: Value(authorNames),
            totalDuration: Value(totalDuration),
            chaptersJson: Value(chaptersJson),
            status: const Value('downloading'),
            progressCurrentTime: Value(progressCurrentTime),
            progressIsFinished: Value(progressIsFinished),
          ),
        );

    await (_db.delete(
      _db.downloadedTracks,
    )..where((t) => t.itemId.equals(downloadId))).go();

    for (final track in tracks) {
      await _db
          .into(_db.downloadedTracks)
          .insert(
            DownloadedTracksCompanion.insert(
              itemId: downloadId,
              trackIndex: track.index,
              startOffset: track.startOffset,
              duration: track.duration,
            ),
          );

      final task = DownloadTask(
        taskId: '${downloadId}__track${track.index}',
        url: audioStreamUrl(
          serverUrl: serverUrl,
          relativeContentUrl: track.contentUrl,
          token: token,
        ),
        filename: 'track_${track.index}.audio',
        directory: _dirFor(downloadId),
        baseDirectory: BaseDirectory.applicationDocuments,
        group: groupFor(downloadId),
        updates: Updates.statusAndProgress,
        metaData: downloadId,
      );
      await FileDownloader().enqueue(task);
    }

    // Best-effort — a missing cover doesn't block "downloaded" status.
    final coverTask = DownloadTask(
      taskId: '${downloadId}__cover',
      url: coverImageUrl(
        serverUrl: serverUrl,
        itemId: coverItemId,
        token: token,
        updatedAt: updatedAt,
      ),
      filename: 'cover.jpg',
      directory: _dirFor(downloadId),
      baseDirectory: BaseDirectory.applicationDocuments,
      group: groupFor(downloadId),
      updates: Updates.status,
      metaData: downloadId,
    );
    await FileDownloader().enqueue(coverTask);
  }

  Future<void> onTrackComplete(Task task) async {
    final itemId = task.metaData;
    if (itemId.isEmpty) return;
    final match = RegExp(r'track(\d+)$').firstMatch(task.taskId);
    if (match == null) return;
    final index = int.parse(match.group(1)!);
    final path = await task.filePath();

    await (_db.update(_db.downloadedTracks)..where(
          (t) => t.itemId.equals(itemId) & t.trackIndex.equals(index),
        ))
        .write(
          DownloadedTracksCompanion(
            localPath: Value(path),
            status: const Value('complete'),
          ),
        );

    final remaining =
        await (_db.select(_db.downloadedTracks)..where(
              (t) => t.itemId.equals(itemId) & t.status.equals('pending'),
            ))
            .get();
    if (remaining.isEmpty) {
      await (_db.update(
        _db.downloadedItems,
      )..where((i) => i.itemId.equals(itemId))).write(
        const DownloadedItemsCompanion(status: Value('complete')),
      );
    }
  }

  Future<void> onCoverComplete(Task task) async {
    final itemId = task.metaData;
    if (itemId.isEmpty) return;
    final path = await task.filePath();
    await (_db.update(
      _db.downloadedItems,
    )..where((i) => i.itemId.equals(itemId))).write(
      DownloadedItemsCompanion(coverLocalPath: Value(path)),
    );
  }

  Future<bool> isDownloaded(String itemId) async {
    final row =
        await (_db.select(
          _db.downloadedItems,
        )..where((i) => i.itemId.equals(itemId))).getSingleOrNull();
    return row?.status == 'complete';
  }

  /// Keeps the local progress cache fresh so a downloaded item resumes from
  /// where playback actually left off, not from wherever it happened to be
  /// when the download started. Called by [PlaybackController] alongside
  /// every server sync — a no-op if this item was never downloaded.
  Future<void> updateLocalProgress({
    required String itemId,
    required double currentTime,
    required bool isFinished,
  }) async {
    await (_db.update(
      _db.downloadedItems,
    )..where((i) => i.itemId.equals(itemId))).write(
      DownloadedItemsCompanion(
        progressCurrentTime: Value(currentTime),
        progressIsFinished: Value(isFinished),
      ),
    );
  }

  Future<List<DownloadedTrack>> localTracksFor(String itemId) {
    return (_db.select(_db.downloadedTracks)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.asc(t.trackIndex)]))
        .get();
  }

  /// Rebuilds a playable [LibraryItemDetail] from local data only — no
  /// network call. Returns null if the item isn't fully downloaded.
  Future<LibraryItemDetail?> buildOfflineItemDetail(String itemId) async {
    final row =
        await (_db.select(
          _db.downloadedItems,
        )..where((i) => i.itemId.equals(itemId))).getSingleOrNull();
    if (row == null || row.status != 'complete') return null;

    final tracks = await localTracksFor(itemId);
    if (tracks.isEmpty || tracks.any((t) => t.localPath == null)) return null;

    var chapters = const <BookChapter>[];
    final chaptersJson = row.chaptersJson;
    if (chaptersJson != null) {
      final decoded = jsonDecode(chaptersJson) as List<dynamic>;
      chapters = decoded
          .cast<Map<String, dynamic>>()
          .map(BookChapter.fromJson)
          .toList();
    }

    // A composite key means this row is a podcast episode: split it back into
    // the parent podcast id (for cover/progress) and the episode id.
    final episodeIds = _episodeIdsFromDownloadId(row.itemId);
    final id = episodeIds?.$1 ?? row.itemId;
    final episodeId = episodeIds?.$2;

    return LibraryItemDetail(
      id: id,
      episodeId: episodeId,
      mediaType: episodeId == null ? 'book' : 'podcast',
      coverPath: null,
      updatedAt: 0,
      title: row.title,
      subtitle: null,
      authors: row.authorNames.isEmpty
          ? const []
          : [AuthorRef(id: '', name: row.authorNames)],
      narrators: const [],
      series: const [],
      genres: const [],
      description: null,
      publishedYear: null,
      duration: row.totalDuration,
      chapters: chapters,
      hasEbook: false,
      progress: row.progressCurrentTime == null
          ? null
          : MediaProgress(
              currentTime: row.progressCurrentTime!,
              isFinished: row.progressIsFinished,
              progress: (row.totalDuration ?? 0) > 0
                  ? (row.progressCurrentTime! / row.totalDuration!).clamp(
                      0,
                      1,
                    )
                  : 0,
            ),
      tracks: tracks
          .map(
            (t) => AudioTrack(
              index: t.trackIndex,
              contentUrl: t.localPath ?? '',
              duration: t.duration,
              startOffset: t.startOffset,
            ),
          )
          .toList(),
    );
  }

  Stream<List<DownloadedItem>> watchDownloads() {
    return _db.select(_db.downloadedItems).watch();
  }

  Future<void> deleteDownload(String itemId) async {
    final tracks = await localTracksFor(itemId);
    for (final t in tracks) {
      final path = t.localPath;
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) await file.delete();
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final itemDir = Directory('${docsDir.path}/${_dirFor(itemId)}');
    if (await itemDir.exists()) await itemDir.delete(recursive: true);

    await (_db.delete(
      _db.downloadedTracks,
    )..where((t) => t.itemId.equals(itemId))).go();
    await (_db.delete(
      _db.downloadedItems,
    )..where((i) => i.itemId.equals(itemId))).go();
  }

  /// PLAN.md Phase 6.10: on-disk size of one downloaded item (all track
  /// files + cover), for the Downloads screen's per-item size label and
  /// total-storage-used figure. Reads real file sizes rather than trusting
  /// track `duration`/bitrate estimates.
  Future<int> sizeOfItem(String itemId) async {
    var total = 0;
    for (final track in await localTracksFor(itemId)) {
      final path = track.localPath;
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) total += await file.length();
    }
    final row =
        await (_db.select(
          _db.downloadedItems,
        )..where((i) => i.itemId.equals(itemId))).getSingleOrNull();
    final coverPath = row?.coverLocalPath;
    if (coverPath != null) {
      final file = File(coverPath);
      if (await file.exists()) total += await file.length();
    }
    return total;
  }

  /// PLAN.md Phase 6.10: bulk-delete every downloaded item.
  Future<void> deleteAllDownloads() async {
    final items = await _db.select(_db.downloadedItems).get();
    for (final item in items) {
      await deleteDownload(item.itemId);
    }
  }
}
