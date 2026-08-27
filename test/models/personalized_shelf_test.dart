import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/models/personalized_shelf.dart';

void main() {
  group('PersonalizedShelf.fromJson', () {
    test(
      'a series-type shelf keeps full LibrarySeries entries, not just names',
      () {
        final shelf = PersonalizedShelf.fromJson({
          'id': 'recent-series',
          'label': 'Recent Series',
          'type': 'series',
          'entities': [
            {
              'id': 'series-1',
              'name': 'Moral Letters',
              'books': [
                {
                  'id': 'book-1',
                  'mediaType': 'book',
                  'updatedAt': 123,
                  'media': {
                    'metadata': {'title': 'Vol. I'},
                  },
                },
              ],
            },
          ],
        });

        expect(shelf.type, ShelfEntityType.series);
        expect(shelf.seriesEntries, hasLength(1));
        expect(shelf.seriesEntries.single.id, 'series-1');
        expect(shelf.seriesEntries.single.name, 'Moral Letters');
        // The whole point of this change: a cover-eligible book id survives,
        // where the old `List<String>` shape discarded everything but name.
        expect(shelf.seriesEntries.single.coverItem?.id, 'book-1');
      },
    );

    test('an item-type shelf is unaffected', () {
      final shelf = PersonalizedShelf.fromJson({
        'id': 'continue-listening',
        'label': 'Continue Listening',
        'type': 'book',
        'entities': [
          {
            'id': 'book-1',
            'mediaType': 'book',
            'updatedAt': 1,
            'media': {
              'metadata': {'title': 'A Book'},
            },
          },
        ],
      });

      expect(shelf.type, ShelfEntityType.item);
      expect(shelf.items, hasLength(1));
      expect(shelf.seriesEntries, isEmpty);
    });
  });
}
