import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/library/author_book_order.dart';
import 'package:steeped/models/library_browse.dart';
import 'package:steeped/models/library_item.dart';
import 'package:steeped/models/library_series.dart';

LibraryItem book(String id, String title, {String? seq}) => LibraryItem(
  id: id,
  mediaType: 'book',
  coverPath: null,
  updatedAt: 0,
  title: title,
  subtitle: null,
  authorOrPublisherName: null,
  seriesName: null,
  duration: null,
  hasEbook: false,
  seriesSequence: seq,
);

void main() {
  test('series by name, books by numeric sequence, standalone last', () {
    final b1 = book('1', 'Z-one', seq: '1');
    final b2 = book('2', 'Y-two', seq: '2');
    final b10 = book('10', 'X-ten', seq: '10');
    final b15 = book('15', 'W-half', seq: '1.5');
    final loose = book('9', 'Alone');
    final other = book('7', 'Other', seq: '1');
    final author = Author(
      id: 'a',
      name: 'A',
      description: null,
      imagePath: null,
      numBooks: 6,
      updatedAt: 0,
      books: [loose, b10, other, b2, b1, b15],
      series: [
        LibrarySeries(id: 's2', name: 'Zeta', books: [other]),
        LibrarySeries(id: 's1', name: 'Alpha', books: [b10, b2, b1, b15]),
      ],
    );
    expect(authorBooksInReadingOrder(author).map((b) => b.id), [
      '1',
      '15',
      '2',
      '10',
      '7',
      '9',
    ]);
  });

  test('a book in two series appears once', () {
    final b = book('1', 'Shared', seq: '1');
    final author = Author(
      id: 'a',
      name: 'A',
      description: null,
      imagePath: null,
      numBooks: 1,
      updatedAt: 0,
      books: [b],
      series: [
        LibrarySeries(id: 's1', name: 'A', books: [b]),
        LibrarySeries(id: 's2', name: 'B', books: [b]),
      ],
    );
    expect(authorBooksInReadingOrder(author), hasLength(1));
  });

  test('compareSequence puts missing/non-numeric last', () {
    expect(compareSequence('2', '10'), lessThan(0));
    expect(compareSequence(null, '1'), greaterThan(0));
    expect(compareSequence('1', null), lessThan(0));
  });
}
