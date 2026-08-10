import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/app_database.dart';
import '../../../models/ebook_file.dart';
import '../../../models/library_item_detail.dart';
import 'ereader_settings.dart';

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

    final response = await _dio.get<List<int>>(
      '/api/items/${item.id}/file/${ebookFile.ino}',
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (total <= 0 || onProgress == null) return;
        onProgress(received / total);
      },
    );
    await file.writeAsBytes(response.data ?? const []);
    return file;
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
