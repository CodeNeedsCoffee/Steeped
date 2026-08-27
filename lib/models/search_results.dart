import 'library_item.dart';
import 'library_series.dart';

/// `GET /api/libraries/:id/search?q=...` — confirmed live against a real
/// Audiobookshelf server that the response is grouped by category: `book`,
/// `series`, `authors`, `narrators`, `tags`, `genres`. PLAN.md Phase 4.7
/// (partial): only Books + Series are surfaced for v1 — the rest have
/// nowhere to navigate to yet (no author/tag/genre browse screens).
class SearchResults {
  const SearchResults({required this.books, required this.series});

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    final bookEntries =
        (json['book'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        const [];
    final seriesEntries =
        (json['series'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        const [];

    return SearchResults(
      books: bookEntries
          .map((e) => e['libraryItem'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map(LibraryItem.fromJson)
          .toList(),
      // Unlike /series (which nests books inside the series object), a
      // search hit's series entry is `{series: {...}, books: [...]}` --
      // merge the two before reusing LibrarySeries.fromJson unchanged.
      series: seriesEntries
          .map((e) {
            final series = e['series'] as Map<String, dynamic>?;
            if (series == null) return null;
            return LibrarySeries.fromJson({...series, 'books': e['books']});
          })
          .whereType<LibrarySeries>()
          .toList(),
    );
  }

  final List<LibraryItem> books;
  final List<LibrarySeries> series;

  bool get isEmpty => books.isEmpty && series.isEmpty;
}
