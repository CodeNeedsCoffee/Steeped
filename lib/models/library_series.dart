import 'library_item.dart';

/// A series, from `GET /api/libraries/:id/series` (`results[]`) or a
/// `type: 'series'` personalized shelf's `entities[]` — same server `Series`
/// object shape in both cases (confirmed live against `/series` on a real
/// Audiobookshelf server: `{id, name, nameIgnorePrefix, description, books:
/// [<LibraryItemMinified>...]}`). Audiobookshelf has no series-level cover
/// endpoint — `coverItem` (the first book) is what every series cover comes
/// from, via the same `coverImageUrl`/`CoverImage` every book cover uses.
class LibrarySeries {
  const LibrarySeries({required this.id, required this.name, required this.books});

  factory LibrarySeries.fromJson(Map<String, dynamic> json) {
    final books =
        (json['books'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .map(LibraryItem.fromJson)
            .toList() ??
        const [];
    return LibrarySeries(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Series',
      books: books,
    );
  }

  final String id;
  final String name;
  final List<LibraryItem> books;

  LibraryItem? get coverItem => books.isEmpty ? null : books.first;
}
