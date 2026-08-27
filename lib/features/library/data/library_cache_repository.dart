import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../../../models/library.dart';

/// Last-known library list, persisted so a cold start with no connectivity
/// can still build the library picker (and decide book-vs-podcast tabs)
/// instead of dead-ending on the `librariesProvider` failure. Same
/// KV-blob shape as [AppSettingsRepository].
class LibraryCacheRepository {
  LibraryCacheRepository(this._db);

  final AppDatabase _db;
  static const _key = 'cached_libraries';

  Future<List<Library>> load() async {
    final row =
        await (_db.select(
          _db.keyValueEntries,
        )..where((t) => t.key.equals(_key))).getSingleOrNull();
    if (row == null) return const [];
    try {
      final decoded = jsonDecode(row.value) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>().map(Library.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<Library> libraries) {
    return _db
        .into(_db.keyValueEntries)
        .insertOnConflictUpdate(
          KeyValueEntriesCompanion.insert(
            key: _key,
            value: jsonEncode(libraries.map((l) => l.toJson()).toList()),
          ),
        );
  }
}
