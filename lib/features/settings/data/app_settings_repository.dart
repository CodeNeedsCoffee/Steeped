import 'dart:convert';

import '../../../core/storage/app_database.dart';
import 'app_settings.dart';

class AppSettingsRepository {
  AppSettingsRepository(this._db);

  final AppDatabase _db;
  static const _key = 'app_settings';

  Future<AppSettings> load() async {
    final row =
        await (_db.select(
          _db.keyValueEntries,
        )..where((t) => t.key.equals(_key))).getSingleOrNull();
    if (row == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
        jsonDecode(row.value) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) {
    return _db
        .into(_db.keyValueEntries)
        .insertOnConflictUpdate(
          KeyValueEntriesCompanion.insert(
            key: _key,
            value: jsonEncode(settings.toJson()),
          ),
        );
  }
}
