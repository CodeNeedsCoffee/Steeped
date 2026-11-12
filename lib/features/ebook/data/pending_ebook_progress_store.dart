import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../../auth/data/server_profile_repository.dart' show profileScopedKey;

/// A reading position the server has not accepted yet.
class PendingEbookProgress {
  const PendingEbookProgress({
    required this.itemId,
    required this.location,
    required this.fraction,
    required this.at,
    this.isFinished,
  });

  factory PendingEbookProgress.fromJson(String itemId, Map<String, dynamic> j) =>
      PendingEbookProgress(
        itemId: itemId,
        location: j['location'] as String? ?? '',
        fraction: (j['fraction'] as num?)?.toDouble() ?? 0,
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
        isFinished: j['isFinished'] as bool?,
      );

  final String itemId;
  final String location;
  final double fraction;

  /// When the reader recorded it; used to avoid overwriting a newer position
  /// saved from another device.
  final DateTime at;
  final bool? isFinished;

  Map<String, dynamic> toJson() => {
    'location': location,
    'fraction': fraction,
    'at': at.millisecondsSinceEpoch,
    if (isFinished != null) 'isFinished': isFinished,
  };
}

/// H9: reading positions whose upload failed (offline, server hiccup), one per
/// item (the newest wins), kept on the device per server profile until the
/// sync controller delivers them. Audio has the same kind of durable queue.
class PendingEbookProgressStore {
  PendingEbookProgressStore(this._db, {this.profileId = ''});

  final AppDatabase _db;
  final String profileId;

  String get _key => profileId.isEmpty
      ? 'pending_ebook_progress'
      : profileScopedKey(profileId, 'pending_ebook_progress');

  Future<Map<String, PendingEbookProgress>> _load() async {
    final row = await (_db.select(
      _db.keyValueEntries,
    )..where((t) => t.key.equals(_key))).getSingleOrNull();
    if (row == null) return {};
    try {
      return {
        for (final e in (jsonDecode(row.value) as Map<String, dynamic>).entries)
          e.key: PendingEbookProgress.fromJson(
            e.key,
            e.value as Map<String, dynamic>,
          ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<PendingEbookProgress>> pending() async =>
      (await _load()).values.toList();

  Future<void> put(PendingEbookProgress p) async {
    final all = await _load();
    final existing = all[p.itemId];
    // Keep the "finished" flag if an earlier unsent position carried it and
    // this one does not say otherwise.
    all[p.itemId] = PendingEbookProgress(
      itemId: p.itemId,
      location: p.location,
      fraction: p.fraction,
      at: p.at,
      isFinished: p.isFinished ?? existing?.isFinished,
    );
    await _write(all);
  }

  /// Removes [itemId]'s row, unless a newer position replaced it while it was
  /// being uploaded ([sentAt] is the time of the one that was sent).
  Future<void> remove(String itemId, {DateTime? sentAt}) async {
    final all = await _load();
    final row = all[itemId];
    if (row == null) return;
    if (sentAt != null && row.at.isAfter(sentAt)) return;
    all.remove(itemId);
    await _write(all);
  }

  Future<void> _write(Map<String, PendingEbookProgress> all) => _db
      .into(_db.keyValueEntries)
      .insertOnConflictUpdate(
        KeyValueEntriesCompanion.insert(
          key: _key,
          value: jsonEncode({for (final e in all.entries) e.key: e.value.toJson()}),
        ),
      );
}
