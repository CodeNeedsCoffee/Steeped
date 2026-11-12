import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/models/library_browse.dart';
import 'package:steeped/models/library_item.dart';

LibraryItem book({required bool audio}) => LibraryItem(
  id: 'b',
  mediaType: 'book',
  coverPath: null,
  updatedAt: 0,
  title: 't',
  subtitle: null,
  authorOrPublisherName: null,
  seriesName: null,
  duration: null,
  hasEbook: true,
  hasAudio: audio,
);

PlaylistItem entry(LibraryItem? item, {String? episode}) => PlaylistItem(
  libraryItemId: 'b',
  episodeId: episode,
  item: item,
  episodeTitle: null,
  duration: null,
);

void main() {
  test('a book with audio is playable', () {
    expect(entry(book(audio: true)).isPlayable, isTrue);
  });

  test('an ebook-only book is not playable', () {
    expect(entry(book(audio: false)).isPlayable, isFalse);
  });

  test('a podcast episode entry is not a whole-book queue item', () {
    expect(entry(book(audio: true), episode: 'e1').isPlayable, isFalse);
  });

  test('an entry with no item data is assumed playable', () {
    expect(entry(null).isPlayable, isTrue);
  });
}
