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

/// PLAN.md Phase 6.1/6.4/6.6: downloads server items for offline playback.
/// [buildOfflineItemDetail] reconstructs a fully playable item from local
/// drift rows alone — no network call — which is what makes offline
/// playback genuinely work with zero connectivity, not just "play from
/// cache while still checking the server."
class DownloadRepository {
  DownloadRepository(this._db);

  final AppDatabase _db;

  static String groupFor(String itemId) => 'download-$itemId';
  static String _dirFor(String itemId) => 'steeped_downloads/$itemId';

  Future<void> startDownload({
    required LibraryItemDetail item,
    required String serverUrl,
    required String? token,
  }) async {
    final chaptersJson = jsonEncode(
      item.chapters
          .map((c) => {'title': c.title, 'start': c.start, 'end': c.end})
          .toList(),
    );

    await _db
        .into(_db.downloadedItems)
        .insertOnConflictUpdate(
          DownloadedItemsCompanion.insert(
            itemId: item.id,
            serverUrl: serverUrl,
            title: item.title,
            authorNames: Value(item.authorNames),
            totalDuration: Value(item.duration),
            chaptersJson: Value(chaptersJson),
            status: const Value('downloading'),
            progressCurrentTime: Value(item.progress?.currentTime),
            progressIsFinished: Value(item.progress?.isFinished ?? false),
          ),
        );

    await (_db.delete(
      _db.downloadedTracks,
    )..where((t) => t.itemId.equals(item.id))).go();

    for (final track in item.tracks) {
      await _db
          .into(_db.downloadedTracks)
          .insert(
            DownloadedTracksCompanion.insert(
              itemId: item.id,
              trackIndex: track.index,
              startOffset: track.startOffset,
              duration: track.duration,
            ),
          );

      final task = DownloadTask(
        taskId: '${item.id}__track${track.index}',
        url: audioStreamUrl(
          serverUrl: serverUrl,
          relativeContentUrl: track.contentUrl,
          token: token,
        ),
        filename: 'track_${track.index}.audio',
        directory: _dirFor(item.id),
        baseDirectory: BaseDirectory.applicationDocuments,
        group: groupFor(item.id),
        updates: Updates.statusAndProgress,
        metaData: item.id,
      );
      await FileDownloader().enqueue(task);
    }

    // Best-effort — a missing cover doesn't block "downloaded" status.
    final coverTask = DownloadTask(
      taskId: '${item.id}__cover',
      url: coverImageUrl(
        serverUrl: serverUrl,
        itemId: item.id,
        token: token,
        updatedAt: item.updatedAt,
      ),
      filename: 'cover.jpg',
      directory: _dirFor(item.id),
      baseDirectory: BaseDirectory.applicationDocuments,
      group: groupFor(item.id),
      updates: Updates.status,
      metaData: item.id,
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

    return LibraryItemDetail(
      id: row.itemId,
      mediaType: 'book',
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
}
