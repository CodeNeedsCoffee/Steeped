import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/models/library_series.dart';

void main() {
  group('LibrarySeries.fromJson', () {
    // Shape confirmed live against GET /api/libraries/:id/series on a real
    // Audiobookshelf server -- books[] are full LibraryItemMinified objects.
    test('parses id, name, and books', () {
      final series = LibrarySeries.fromJson({
        'id': '6d6d0742-4cb5-4ae7-9c68-2c626729f0bc',
        'name': 'Moral Letters',
        'nameIgnorePrefix': 'Moral Letters',
        'books': [
          {
            'id': '2598d7de-116e-4ec6-8ef9-7b90cacb36d7',
            'mediaType': 'book',
            'updatedAt': 1732632313745,
            'media': {
              'coverPath': '/metadata/items/2598.../cover.jpg',
              'metadata': {
                'title': 'Moral Letters, Vol. I',
                'authorName': 'Lucius Annaeus Seneca',
              },
            },
          },
        ],
      });

      expect(series.id, '6d6d0742-4cb5-4ae7-9c68-2c626729f0bc');
      expect(series.name, 'Moral Letters');
      expect(series.books, hasLength(1));
      expect(series.books.first.title, 'Moral Letters, Vol. I');
      expect(series.coverItem, same(series.books.first));
    });

    test('coverItem is null when there are no books', () {
      final series = LibrarySeries.fromJson({
        'id': 'x',
        'name': 'Empty Series',
        'books': <Map<String, dynamic>>[],
      });
      expect(series.coverItem, isNull);
    });

    test('defaults gracefully on a bare/missing shape', () {
      final series = LibrarySeries.fromJson(const {});
      expect(series.id, '');
      expect(series.name, 'Series');
      expect(series.books, isEmpty);
    });
  });
}
