import 'dart:convert';

import '../../core/storage/app_database.dart';
import '../auth/data/server_profile_repository.dart' show profileScopedKey;
import 'streak.dart' show dayKey;

/// G1: active reading seconds per local date, per server profile. The server
/// only counts playback sessions, so reading is kept on the device.
class ReadingDaysStore {
  ReadingDaysStore(this._db, {this.profileId = ''});

  final AppDatabase _db;
  final String profileId;

  String get _key => profileId.isEmpty
      ? 'reading_days'
      : profileScopedKey(profileId, 'reading_days');

  Future<Map<String, int>> load() async {
    final row = await (_db.select(
      _db.keyValueEntries,
    )..where((t) => t.key.equals(_key))).getSingleOrNull();
    if (row == null) return const {};
    try {
      return (jsonDecode(row.value) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
    } catch (_) {
      return const {};
    }
  }

  Future<void> add(DateTime day, int seconds) async {
    if (seconds <= 0) return;
    final all = {...await load()};
    all.update(dayKey(day), (v) => v + seconds, ifAbsent: () => seconds);
    await _db
        .into(_db.keyValueEntries)
        .insertOnConflictUpdate(
          KeyValueEntriesCompanion.insert(key: _key, value: jsonEncode(all)),
        );
  }
}

/// Turns reader activity into reading seconds. Each [touch] (a page turn,
/// scroll or tap) credits the time since the previous one, unless more than
/// [idle] passed, in which case the gap counts for nothing: a book left open
/// on a table adds no reading time.
class ReadingClock {
  ReadingClock({this.idle = const Duration(minutes: 2)});

  final Duration idle;
  DateTime? _last;
  Duration _pending = Duration.zero;

  void touch(DateTime now) {
    final last = _last;
    if (last != null) {
      final gap = now.difference(last);
      if (gap > Duration.zero && gap <= idle) _pending += gap;
    }
    _last = now;
  }

  /// Whole seconds earned since the last call. The fraction stays banked:
  /// scrolling fires touches every few milliseconds, so flooring each gap
  /// would credit nothing.
  int takePending() {
    final whole = _pending.inSeconds;
    _pending -= Duration(seconds: whole);
    return whole;
  }

  /// Forget the last touch (the reader was backgrounded or closed).
  void pause() => _last = null;
}
