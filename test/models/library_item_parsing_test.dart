import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/models/library_item.dart';
import 'package:steeped/models/library_query.dart';

void main() {
  test('collapsedSeries and series sequence are parsed', () {
    final item = LibraryItem.fromJson({
      'id': 'x',
      'mediaType': 'book',
      'media': {
        'metadata': {
          'title': 'T',
          'series': {'id': 's', 'name': 'N', 'sequence': '3'},
        },
      },
      'collapsedSeries': {'id': 's', 'name': 'N', 'numBooks': 5},
    });
    expect(item.seriesSequence, '3');
    expect(item.collapsedSeries?.numBooks, 5);
    expect(item.collapsedSeries?.id, 's');
  });

  test('plain items have neither', () {
    final item = LibraryItem.fromJson({
      'id': 'x',
      'media': {
        'metadata': {'title': 'T', 'seriesName': 'N #1'},
      },
    });
    expect(item.collapsedSeries, isNull);
    expect(item.seriesSequence, isNull);
  });

  group('LibraryQuery', () {
    test('section round-trips and survives filter changes', () {
      final q = const LibraryQuery().copyWith(section: 'authors');
      expect(LibraryQuery.fromJson(q.toJson()).section, 'authors');
      expect(
        q.withFilter(LibraryFilterGroup.ebooks, 'ebook').section,
        'authors',
      );
      expect(q.withoutFilter().section, 'authors');
    });

    test('old JSON without a section defaults to books', () {
      expect(LibraryQuery.fromJson({'sort': 'title'}).section, 'books');
    });

    test('ebook filter encodes as ebooks.<base64>', () {
      final q = const LibraryQuery().withFilter(
        LibraryFilterGroup.ebooks,
        'ebook',
      );
      expect(q.filterParam, 'ebooks.ZWJvb2s=');
    });
  });
}
