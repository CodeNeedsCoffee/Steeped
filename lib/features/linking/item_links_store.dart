import 'dart:convert';

import '../../core/storage/app_database.dart';
import '../auth/data/server_profile_repository.dart' show profileScopedKey;

/// How a link came to exist.
enum LinkSource { sameItem, auto, manual }

class ItemLink {
  const ItemLink({
    required this.audioItemId,
    required this.ebookItemId,
    required this.source,
  });

  factory ItemLink.fromJson(Map<String, dynamic> json) => ItemLink(
    audioItemId: json['audio'] as String,
    ebookItemId: json['ebook'] as String,
    source: LinkSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => LinkSource.manual,
    ),
  );

  final String audioItemId;
  final String ebookItemId;
  final LinkSource source;

  Map<String, dynamic> toJson() => {
    'audio': audioItemId,
    'ebook': ebookItemId,
    'source': source.name,
  };

  /// The item on the other side of the link from [itemId].
  String otherSide(String itemId) =>
      itemId == audioItemId ? ebookItemId : audioItemId;
}

/// J1: links between an audiobook item and an ebook item. The server cannot
/// store them, so they live on the device in [KeyValueEntries], one JSON list
/// per server profile (a link is only meaningful against that server's ids).
class ItemLinksStore {
  ItemLinksStore(this._db, {this.profileId = ''});

  final AppDatabase _db;
  final String profileId;

  String get _key => profileId.isEmpty
      ? 'item_links'
      : profileScopedKey(profileId, 'item_links');

  Future<List<ItemLink>> load() async {
    final row = await (_db.select(
      _db.keyValueEntries,
    )..where((t) => t.key.equals(_key))).getSingleOrNull();
    if (row == null) return const [];
    try {
      return [
        for (final e in jsonDecode(row.value) as List<dynamic>)
          ItemLink.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// The link that involves [itemId], on either side.
  Future<ItemLink?> forItem(String itemId) async {
    for (final l in await load()) {
      if (l.audioItemId == itemId || l.ebookItemId == itemId) return l;
    }
    return null;
  }

  /// Saves [link], replacing any existing link that uses either item.
  Future<void> save(ItemLink link) async {
    final kept = [
      for (final l in await load())
        if (l.audioItemId != link.audioItemId &&
            l.ebookItemId != link.ebookItemId)
          l,
    ];
    await _write([...kept, link]);
  }

  Future<void> remove(String itemId) async {
    await _write([
      for (final l in await load())
        if (l.audioItemId != itemId && l.ebookItemId != itemId) l,
    ]);
  }

  Future<void> _write(List<ItemLink> links) => _db
      .into(_db.keyValueEntries)
      .insertOnConflictUpdate(
        KeyValueEntriesCompanion.insert(
          key: _key,
          value: jsonEncode([for (final l in links) l.toJson()]),
        ),
      );
}
