import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/models/search_results.dart';

void main() {
  group('SearchResults.fromJson', () {
    // Shape confirmed live against GET /api/libraries/:id/search on a real
    // Audiobookshelf server: grouped by category, book results wrapped as
    // {libraryItem: {...}}, series results as a SIBLING {series, books}
    // pair rather than /series's nested {series: {..., books: [...]}}.
    test('unwraps book.libraryItem entries', () {
      final results = SearchResults.fromJson({
        'book': [
          {
            'libraryItem': {
              'id': 'book-1',
              'mediaType': 'book',
              'updatedAt': 1,
              'media': {
                'metadata': {'title': 'The Invisible Man'},
              },
            },
          },
        ],
        'series': <Map<String, dynamic>>[],
        'authors': <Map<String, dynamic>>[],
        'narrators': <Map<String, dynamic>>[],
        'tags': <Map<String, dynamic>>[],
        'genres': <Map<String, dynamic>>[],
      });

      expect(results.books, hasLength(1));
      expect(results.books.single.title, 'The Invisible Man');
      expect(results.series, isEmpty);
    });

    test('merges the sibling {series, books} shape into one LibrarySeries', () {
      final results = SearchResults.fromJson({
        'book': <Map<String, dynamic>>[],
        'series': [
          {
            'series': {'id': 'series-1', 'name': 'Moral Letters'},
            'books': [
              {
                'id': 'book-1',
                'mediaType': 'book',
                'updatedAt': 1,
                'media': {
                  'metadata': {'title': 'Vol. I'},
                },
              },
            ],
          },
        ],
      });

      expect(results.series, hasLength(1));
      expect(results.series.single.id, 'series-1');
      expect(results.series.single.name, 'Moral Letters');
      expect(results.series.single.coverItem?.id, 'book-1');
    });

    test('isEmpty is true when both categories are empty', () {
      expect(SearchResults.fromJson(const {}).isEmpty, isTrue);
    });
  });
}
