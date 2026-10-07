import 'library_browse.dart';
import 'library_item.dart';
import 'library_series.dart';

/// A narrator/tag/genre hit: just the name and how many items carry it.
class SearchFacet {
  const SearchFacet({required this.name, required this.count});

  final String name;
  final int count;
}

/// `GET /api/libraries/:id/search?q=...` — grouped by category: `book`,
/// `series`, `authors`, `narrators`, `tags`, `genres` (LIBRARY_PLAN.md L5
/// surfaces all of them).
class SearchResults {
  const SearchResults({
    required this.books,
    required this.series,
    this.authors = const [],
    this.narrators = const [],
    this.tags = const [],
    this.genres = const [],
  });

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(String key) =>
        ((json[key] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    List<SearchFacet> facets(String key) => [
      for (final m in maps(key))
        SearchFacet(
          name: m['name']?.toString() ?? '',
          count: ((m['numItems'] ?? m['numBooks']) as num?)?.toInt() ?? 0,
        ),
    ];

    return SearchResults(
      books: maps('book')
          .map((e) => e['libraryItem'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map(LibraryItem.fromJson)
          .toList(),
      // Unlike /series (which nests books inside the series object), a
      // search hit's series entry is `{series: {...}, books: [...]}` --
      // merge the two before reusing LibrarySeries.fromJson unchanged.
      series: maps('series')
          .map((e) {
            final series = e['series'] as Map<String, dynamic>?;
            if (series == null) return null;
            return LibrarySeries.fromJson({...series, 'books': e['books']});
          })
          .whereType<LibrarySeries>()
          .toList(),
      authors: maps('authors').map(Author.fromJson).toList(),
      narrators: facets('narrators'),
      tags: facets('tags'),
      genres: facets('genres'),
    );
  }

  final List<LibraryItem> books;
  final List<LibrarySeries> series;
  final List<Author> authors;
  final List<SearchFacet> narrators;
  final List<SearchFacet> tags;
  final List<SearchFacet> genres;

  bool get isEmpty =>
      books.isEmpty &&
      series.isEmpty &&
      authors.isEmpty &&
      narrators.isEmpty &&
      tags.isEmpty &&
      genres.isEmpty;
}
