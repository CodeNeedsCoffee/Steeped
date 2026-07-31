import 'library_item.dart';

/// One row from `GET /api/libraries/:id/personalized` — e.g. Continue
/// Listening, Recently Added, Recent Series, Newest Authors. Rendered
/// generically by [type] rather than hardcoding each shelf id/label, since
/// the server already drives which shelves exist. See
/// `~/Code/audiobookshelf/server/models/LibraryItem.js`
/// (`getPersonalizedShelves`).
enum ShelfEntityType { item, series, authors, unknown }

class PersonalizedShelf {
  const PersonalizedShelf({
    required this.id,
    required this.label,
    required this.type,
    required this.items,
    required this.seriesEntries,
    required this.authorEntries,
  });

  factory PersonalizedShelf.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? '';
    final entities =
        (json['entities'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        const [];
    final type = switch (rawType) {
      'book' || 'episode' || 'podcast' => ShelfEntityType.item,
      'series' => ShelfEntityType.series,
      'authors' => ShelfEntityType.authors,
      _ => ShelfEntityType.unknown,
    };

    return PersonalizedShelf(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: type,
      items: type == ShelfEntityType.item
          ? entities.map(LibraryItem.fromJson).toList()
          : const [],
      seriesEntries: type == ShelfEntityType.series
          ? entities
                .map((e) => (e['name'] as String?) ?? 'Series')
                .toList()
          : const [],
      authorEntries: type == ShelfEntityType.authors
          ? entities.map((e) => (e['name'] as String?) ?? 'Author').toList()
          : const [],
    );
  }

  final String id;
  final String label;
  final ShelfEntityType type;
  final List<LibraryItem> items;
  final List<String> seriesEntries;
  final List<String> authorEntries;

  bool get isEmpty =>
      items.isEmpty && seriesEntries.isEmpty && authorEntries.isEmpty;
}
