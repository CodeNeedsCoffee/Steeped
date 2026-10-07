import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/models/library_browse.dart';
import 'package:steeped/models/library_query.dart';

void main() {
  test('filter param is <group>.<base64(value)>', () {
    final q = const LibraryQuery().withFilter(LibraryFilterGroup.genres, 'Sci-Fi');
    expect(q.filterParam, 'genres.U2NpLUZp');
    expect(q.withoutFilter().filterParam, isNull);
  });

  test('query survives a JSON round trip', () {
    final q = const LibraryQuery(sort: LibrarySort.addedAt, desc: true, viewMode: LibraryViewMode.list)
        .withFilter(LibraryFilterGroup.authors, 'au_1', label: 'Frank Herbert');
    final back = LibraryQuery.fromJson(q.toJson());
    expect(back, q);
    expect(back.filterLabel, 'Frank Herbert');
  });

  test('bad saved data falls back to defaults', () {
    final q = LibraryQuery.fromJson({'sort': 'nope', 'filterGroup': 'x'});
    expect(q.sort, LibrarySort.title);
    expect(q.hasFilter, isFalse);
  });

  test('playlist parsing tolerates numeric ids and missing fields', () {
    final p = Playlist.fromJson({
      'id': 5,
      'name': 'Road trip',
      'items': [
        {'libraryItemId': 'a', 'libraryItem': {'id': 'a', 'media': {'metadata': {'title': 'A'}, 'duration': 60}}},
        {'libraryItemId': 'b'},
      ],
    });
    expect(p.id, '5');
    expect(p.items.length, 2);
    expect(p.items.first.title, 'A');
    expect(p.items.last.title, 'Unknown item');
    expect(p.contains('a'), isTrue);
    expect(p.totalDuration, 60);
  });
}
