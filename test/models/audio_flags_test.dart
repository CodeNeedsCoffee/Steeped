import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/models/library_item.dart';
import 'package:steeped/models/library_item_detail.dart';

Map<String, dynamic> _min(Map<String, dynamic> media, {String type = 'book'}) =>
    {
      'id': 'x',
      'mediaType': type,
      'media': {
        'metadata': {'title': 'T'},
        ...media,
      },
    };

void main() {
  group('LibraryItem.hasAudio', () {
    test('an ebook with no audio files has nothing to play', () {
      final item = LibraryItem.fromJson(
        _min({'ebookFormat': 'epub', 'numAudioFiles': 0}),
      );
      expect(item.hasEbook, isTrue);
      expect(item.hasAudio, isFalse);
    });

    test('audio, a missing count and podcasts all keep Play', () {
      expect(LibraryItem.fromJson(_min({'numAudioFiles': 3})).hasAudio, isTrue);
      // Older servers/shapes do not send the count: never hide Play by mistake.
      expect(LibraryItem.fromJson(_min({})).hasAudio, isTrue);
      expect(
        LibraryItem.fromJson(
          _min({'numAudioFiles': 0}, type: 'podcast'),
        ).hasAudio,
        isTrue,
      );
    });

    test('an item with both audio and an ebook keeps Play', () {
      final item = LibraryItem.fromJson(
        _min({'ebookFormat': 'epub', 'numAudioFiles': 12}),
      );
      expect(item.hasAudio, isTrue);
      expect(item.hasEbook, isTrue);
    });
  });

  group('LibraryItemDetail.isEbookOnly', () {
    final ebookFile = {
      'ino': '1',
      'ebookFormat': 'epub',
      'metadata': {'filename': 'a.epub', 'ext': '.epub', 'size': 1},
    };

    test('an ebook with no tracks', () {
      final d = LibraryItemDetail.fromJson(
        _min({'ebookFile': ebookFile, 'tracks': []}),
      );
      expect(d.isEbookOnly, isTrue);
    });

    test('an ebook that also has audio tracks is not ebook-only', () {
      final d = LibraryItemDetail.fromJson(
        _min({
          'ebookFile': ebookFile,
          'tracks': [
            {
              'index': 1,
              'startOffset': 0,
              'duration': 10,
              'title': 't',
              'contentUrl': '/a.mp3',
            },
          ],
        }),
      );
      expect(d.hasEbook, isTrue);
      expect(d.isEbookOnly, isFalse);
    });

    test('an audiobook is not ebook-only', () {
      final d = LibraryItemDetail.fromJson(_min({'tracks': []}));
      expect(d.hasEbook, isFalse);
      expect(d.isEbookOnly, isFalse);
    });
  });
}
