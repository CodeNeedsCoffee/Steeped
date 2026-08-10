import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/app_database.dart';
import '../../../models/audio_track.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/media_progress.dart';

/// PLAN.md Phase 6.8: on-device audio import/scan, with no server involved
/// — a genuinely separate capability from downloading server items (Phase
/// 6). Simplified to single-file import rather than a whole-folder scan:
/// Android scoped storage means arbitrary folder access needs a persisted
/// SAF tree URI whose path resolution is inconsistent across OEMs, while
/// picking individual files resolves to a real, reliable path via
/// `flutter_file_dialog`'s `copyFileToCacheDir`. Covers the actual use case
/// (import audio that never lived on the server) without that reliability
/// risk — tap "Import" once per file.
class LocalMediaRepository {
  LocalMediaRepository(this._db);

  final AppDatabase _db;

  static const _dirName = 'steeped_local_media';

  /// Opens the system file picker, copies the chosen audio file into
  /// permanent app storage (the picker's cache-dir copy isn't guaranteed to
  /// survive OS storage pressure), probes its duration, and records it.
  /// Returns the imported title, or null if the user cancelled.
  Future<String?> importFile() async {
    final pickedPath = await FlutterFileDialog.pickFile(
      params: const OpenFileDialogParams(
        fileExtensionsFilter: [
          'mp3',
          'm4a',
          'm4b',
          'aac',
          'wav',
          'ogg',
          'flac',
        ],
        mimeTypesFilter: ['audio/*'],
      ),
    );
    if (pickedPath == null) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${docsDir.path}/$_dirName');
    await targetDir.create(recursive: true);

    final originalName = pickedPath.split('/').last;
    final id = '${DateTime.now().microsecondsSinceEpoch}_$originalName';
    final targetPath = '${targetDir.path}/$id';
    await File(pickedPath).copy(targetPath);

    final title = originalName.contains('.')
        ? originalName.substring(0, originalName.lastIndexOf('.'))
        : originalName;

    double? duration;
    final probePlayer = AudioPlayer();
    try {
      duration = (await probePlayer.setFilePath(targetPath))?.inSeconds
          .toDouble();
    } catch (_) {
      // Duration display is a nice-to-have — still import the file.
    } finally {
      await probePlayer.dispose();
    }

    await _db
        .into(_db.localMediaItems)
        .insert(
          LocalMediaItemsCompanion.insert(
            id: id,
            title: title,
            localPath: targetPath,
            durationSeconds: Value(duration),
          ),
        );
    return title;
  }

  Stream<List<LocalMediaItem>> watchAll() {
    return (_db.select(
      _db.localMediaItems,
    )..orderBy([(t) => OrderingTerm.desc(t.addedAt)])).watch();
  }

  Future<void> delete(String id) async {
    final row =
        await (_db.select(
          _db.localMediaItems,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) {
      final file = File(row.localPath);
      if (await file.exists()) await file.delete();
    }
    await (_db.delete(
      _db.localMediaItems,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateProgress(String id, double currentTime) async {
    await (_db.update(
      _db.localMediaItems,
    )..where((t) => t.id.equals(id))).write(
      LocalMediaItemsCompanion(progressCurrentTime: Value(currentTime)),
    );
  }

  /// Builds a playable [LibraryItemDetail] from a local row — no network
  /// involved at all, unlike [DownloadRepository.buildOfflineItemDetail]
  /// which reconstructs a *server* item's shape for offline playback.
  Future<LibraryItemDetail?> buildPlayableItem(String id) async {
    final row =
        await (_db.select(
          _db.localMediaItems,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;

    return LibraryItemDetail(
      id: row.id,
      mediaType: 'book',
      coverPath: null,
      updatedAt: 0,
      title: row.title,
      subtitle: null,
      authors: const [],
      narrators: const [],
      series: const [],
      genres: const [],
      description: null,
      publishedYear: null,
      duration: row.durationSeconds,
      chapters: const [],
      hasEbook: false,
      progress: row.progressCurrentTime == null
          ? null
          : MediaProgress(
              currentTime: row.progressCurrentTime!,
              isFinished: false,
              progress: (row.durationSeconds ?? 0) > 0
                  ? (row.progressCurrentTime! / row.durationSeconds!).clamp(
                      0,
                      1,
                    )
                  : 0,
            ),
      isLocalOnly: true,
      tracks: [
        AudioTrack(
          index: 0,
          contentUrl: row.localPath,
          duration: row.durationSeconds ?? 0,
          startOffset: 0,
        ),
      ],
    );
  }
}
