import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/app_database.dart';
import '../../../models/ebook_file.dart';
import '../../../models/library_item_detail.dart';
import 'ereader_settings.dart';
import 'reading_position.dart';

/// PLAN.md Phase 8: fetches an item's `ebookFile` bytes (served by the same
/// generic `GET /api/items/:id/file/:ino` endpoint audio tracks use —
/// confirmed live against evan's real server for both a 44MB EPUB and a
/// 128MB CBZ) and caches it to app storage, since every reader (epub_view,
/// pdfx, and the CBZ page extractor) needs a real local file rather than a
/// stream. Unlike Phase 6 downloads, this is a plain one-shot cache keyed by
/// item id + format, not a queued/resumable background download — reading
/// is on-demand, not a "save for offline" action with its own UI.
class EbookRepository {
  EbookRepository(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  Future<File> _cacheFileFor(String itemId, EbookFile ebookFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/steeped_ebooks');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$itemId${_extFor(ebookFile)}');
  }

  String _extFor(EbookFile ebookFile) {
    final fromFilename = ebookFile.filename.contains('.')
        ? '.${ebookFile.filename.split('.').last}'
        : '';
    return fromFilename.isNotEmpty ? fromFilename : '.${ebookFile.format}';
  }

  /// Returns the local file, downloading it first if not already cached.
  /// [onProgress] receives 0..1 while a real download is in flight (not
  /// called at all on a cache hit).
  Future<File> ensureLocalFile(
    LibraryItemDetail item, {
    void Function(double)? onProgress,
  }) async {
    final ebookFile = item.ebookFile;
    if (ebookFile == null) {
      throw StateError('Item ${item.id} has no ebookFile');
    }
    final file = await _cacheFileFor(item.id, ebookFile);
    if (await file.exists() &&
        await file.length() == ebookFile.size &&
        ebookFile.size > 0) {
      return file;
    }

    // `/ebook` (no file id) serves the item's primary ebook, exactly like the
    // official web and mobile apps. The older `/file/:ino` route 404s whenever
    // the cached `ino` is stale (a rescan or file replace changes it), which
    // showed up as an intermittent "Failed to load ... 404" in the readers.
    final response = await _dio.get<List<int>>(
      '/api/items/${item.id}/ebook',
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (total <= 0 || onProgress == null) return;
        onProgress(received / total);
      },
    );
    final bytes = response.data ?? const <int>[];
    if (bytes.isEmpty) throw StateError('The server sent an empty ebook file');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Drops the cached copy so the next [ensureLocalFile] re-downloads it —
  /// used when a cached file fails to open (truncated or replaced on the
  /// server).
  Future<void> evict(LibraryItemDetail item) async {
    final ebookFile = item.ebookFile;
    if (ebookFile == null) return;
    final file = await _cacheFileFor(item.id, ebookFile);
    if (await file.exists()) await file.delete();
  }

  /// Last-known reading position per item, kept on the device so "pick up
  /// where you left off" works offline and before the server has caught up.
  Future<ReadingPosition?> loadPosition(String itemId) async {
    final row =
        await (_db.select(
          _db.keyValueEntries,
        )..where((t) => t.key.equals('ereader_pos:$itemId'))).getSingleOrNull();
    if (row == null) return null;
    try {
      return ReadingPosition.fromJson(
        jsonDecode(row.value) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePosition(String itemId, ReadingPosition position) {
    return _db
        .into(_db.keyValueEntries)
        .insertOnConflictUpdate(
          KeyValueEntriesCompanion.insert(
            key: 'ereader_pos:$itemId',
            value: jsonEncode(position.toJson()),
          ),
        );
  }

  /// Bookmarks are device-local (the server has no field for them).
  Future<List<EbookBookmark>> loadBookmarks(String itemId) async {
    final row =
        await (_db.select(
          _db.keyValueEntries,
        )..where((t) => t.key.equals('ereader_bm:$itemId'))).getSingleOrNull();
    if (row == null) return const [];
    try {
      return (jsonDecode(row.value) as List)
          .map((e) => EbookBookmark.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveBookmarks(String itemId, List<EbookBookmark> bookmarks) {
    return _db
        .into(_db.keyValueEntries)
        .insertOnConflictUpdate(
          KeyValueEntriesCompanion.insert(
            key: 'ereader_bm:$itemId',
            value: jsonEncode([for (final b in bookmarks) b.toJson()]),
          ),
        );
  }

  Future<List<EbookHighlight>> loadHighlights(String itemId) async {
    final row =
        await (_db.select(
          _db.keyValueEntries,
        )..where((t) => t.key.equals('ereader_hl:$itemId'))).getSingleOrNull();
    if (row == null) return const [];
    try {
      return (jsonDecode(row.value) as List)
          .map((e) => EbookHighlight.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveHighlights(String itemId, List<EbookHighlight> items) {
    return _db
        .into(_db.keyValueEntries)
        .insertOnConflictUpdate(
          KeyValueEntriesCompanion.insert(
            key: 'ereader_hl:$itemId',
            value: jsonEncode([for (final h in items) h.toJson()]),
          ),
        );
  }

  static const _settingsKey = 'ereader_settings';

  Future<EreaderSettings> loadSettings() async {
    final row =
        await (_db.select(
          _db.keyValueEntries,
        )..where((t) => t.key.equals(_settingsKey))).getSingleOrNull();
    if (row == null) return const EreaderSettings();
    try {
      return EreaderSettings.fromJson(
        jsonDecode(row.value) as Map<String, dynamic>,
      );
    } catch (_) {
      return const EreaderSettings();
    }
  }

  Future<void> saveSettings(EreaderSettings settings) {
    return _db
        .into(_db.keyValueEntries)
        .insertOnConflictUpdate(
          KeyValueEntriesCompanion.insert(
            key: _settingsKey,
            value: jsonEncode(settings.toJson()),
          ),
        );
  }
}
