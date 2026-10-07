import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../../../models/library_query.dart';

/// Remembers each library's sort / filter / view mode (LIBRARY_PLAN.md L4),
/// in the same `KeyValueEntries` table the app settings use.
class LibraryQueryStore {
  LibraryQueryStore(this._db);

  final AppDatabase _db;

  String _key(String libraryId) => 'library_query:$libraryId';

  Future<LibraryQuery> load(String libraryId) async {
    final row = await (_db.select(
      _db.keyValueEntries,
    )..where((t) => t.key.equals(_key(libraryId)))).getSingleOrNull();
    if (row == null) return const LibraryQuery();
    try {
      return LibraryQuery.fromJson(jsonDecode(row.value) as Map<String, dynamic>);
    } catch (_) {
      return const LibraryQuery();
    }
  }

  Future<void> save(String libraryId, LibraryQuery query) {
    return _db
        .into(_db.keyValueEntries)
        .insertOnConflictUpdate(
          KeyValueEntriesCompanion.insert(
            key: _key(libraryId),
            value: jsonEncode(query.toJson()),
          ),
        );
  }
}
