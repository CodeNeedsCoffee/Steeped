import 'dart:convert';

import '../../core/storage/app_database.dart';
import '../auth/data/server_profile_repository.dart' show profileScopedKey;

/// A confirmed match between a place in an ebook and a time in its audiobook
/// (found by Precise listening, or chosen with "Play from here"). [word] is
/// how far through the ebook's words, 0..1; [seconds] the audiobook time.
class SyncAnchor {
  const SyncAnchor(this.word, this.seconds);

  factory SyncAnchor.fromJson(Map<String, dynamic> json) =>
      SyncAnchor((json['w'] as num).toDouble(), (json['t'] as num).toDouble());

  final double word;
  final double seconds;

  Map<String, dynamic> toJson() => {'w': word, 't': seconds};
}

const _maxAnchors = 40;

/// [anchors] with [a] added. Anchors it crowds (within 0.2% of the book or 20
/// seconds) or contradicts (a later place at an earlier time) are dropped, the
/// list stays in order, and only the newest [_maxAnchors] are kept.
List<SyncAnchor> mergeAnchor(List<SyncAnchor> anchors, SyncAnchor a) {
  final kept = <SyncAnchor>[
    for (final x in anchors)
      if ((x.word - a.word).abs() >= 0.002 &&
          (x.seconds - a.seconds).abs() >= 20 &&
          ((x.word < a.word) == (x.seconds < a.seconds)))
        x,
  ];
  kept.add(a);
  kept.sort((p, q) => p.word.compareTo(q.word));
  return kept.length <= _maxAnchors
      ? kept
      : kept.sublist(kept.length - _maxAnchors);
}

// How far from a lone anchor (as a share of the book) a guess may still lean
// on it; beyond that the ordinary estimate is as good.
const _reach = 0.1;

/// The audiobook time for ebook place [word], interpolating between the anchors
/// on either side, or leaning on the one near it ([duration] is the audiobook's
/// length, used as the seconds per whole book). Null when no anchor helps.
double? secondsFor(List<SyncAnchor> anchors, double word, double duration) {
  SyncAnchor? below, above;
  for (final a in anchors) {
    if (a.word <= word && (below == null || a.word > below.word)) below = a;
    if (a.word >= word && (above == null || a.word < above.word)) above = a;
  }
  if (below != null && above != null) {
    final span = above.word - below.word;
    if (span <= 0) return below.seconds;
    return below.seconds +
        (word - below.word) / span * (above.seconds - below.seconds);
  }
  final lone = below ?? above;
  if (lone == null || (lone.word - word).abs() > _reach) return null;
  return lone.seconds + (word - lone.word) * duration;
}

/// The ebook place (0..1 by words) for audiobook time [seconds]; the mirror of
/// [secondsFor].
double? wordFor(List<SyncAnchor> anchors, double seconds, double duration) {
  if (duration <= 0) return null;
  SyncAnchor? before, after;
  for (final a in anchors) {
    if (a.seconds <= seconds &&
        (before == null || a.seconds > before.seconds)) {
      before = a;
    }
    if (a.seconds >= seconds && (after == null || a.seconds < after.seconds)) {
      after = a;
    }
  }
  if (before != null && after != null) {
    final span = after.seconds - before.seconds;
    if (span <= 0) return before.word;
    return before.word +
        (seconds - before.seconds) / span * (after.word - before.word);
  }
  final lone = before ?? after;
  if (lone == null || (lone.seconds - seconds).abs() / duration > _reach) {
    return null;
  }
  return (lone.word + (seconds - lone.seconds) / duration).clamp(0.0, 1.0);
}

/// Anchors per ebook, kept on the device (in the key-value table), so the
/// longer a book is used the closer the first guess gets.
class SyncAnchorStore {
  SyncAnchorStore(this._db, {this.profileId = ''});

  final AppDatabase _db;
  final String profileId;

  String _key(String ebookId) => profileId.isEmpty
      ? 'sync_anchors:$ebookId'
      : profileScopedKey(profileId, 'sync_anchors:$ebookId');

  Future<List<SyncAnchor>> load(String ebookId) async {
    final row = await (_db.select(
      _db.keyValueEntries,
    )..where((t) => t.key.equals(_key(ebookId)))).getSingleOrNull();
    if (row == null) return const [];
    try {
      return [
        for (final e in jsonDecode(row.value) as List<dynamic>)
          SyncAnchor.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(String ebookId, SyncAnchor anchor) async {
    final merged = mergeAnchor(await load(ebookId), anchor);
    await _db
        .into(_db.keyValueEntries)
        .insertOnConflictUpdate(
          KeyValueEntriesCompanion.insert(
            key: _key(ebookId),
            value: jsonEncode([for (final a in merged) a.toJson()]),
          ),
        );
  }
}
