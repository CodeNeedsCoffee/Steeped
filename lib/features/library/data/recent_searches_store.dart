import 'dart:convert';

import '../../../core/storage/app_database.dart';

/// LIBRARY_PLAN.md L5: the last few search terms, kept on the device.
class RecentSearchesStore {
  RecentSearchesStore(this._db);

  final AppDatabase _db;
  static const _key = 'recent_searches';
  static const maxEntries = 10;

  Future<List<String>> load() async {
    final row = await (_db.select(
      _db.keyValueEntries,
    )..where((t) => t.key.equals(_key))).getSingleOrNull();
    if (row == null) return const [];
    try {
      return (jsonDecode(row.value) as List<dynamic>).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> add(String term) async {
    final t = term.trim();
    if (t.isEmpty) return load();
    final list = [t, ...(await load()).where((e) => e.toLowerCase() != t.toLowerCase())]
        .take(maxEntries)
        .toList();
    await _save(list);
    return list;
  }

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> list) => _db
      .into(_db.keyValueEntries)
      .insertOnConflictUpdate(
        KeyValueEntriesCompanion.insert(key: _key, value: jsonEncode(list)),
      );
}
