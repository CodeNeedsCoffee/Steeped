import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/ebook/state/ebook_providers.dart';

void main() {
  test('an ebook-only item is marked finished at the end', () {
    expect(ebookFinishedFlag(reachedEnd: true, hasAudio: false), isTrue);
  });

  test('an item with audio is never marked finished by its ebook', () {
    expect(ebookFinishedFlag(reachedEnd: true, hasAudio: true), isNull);
  });

  test('mid-book sends nothing either way', () {
    expect(ebookFinishedFlag(reachedEnd: false, hasAudio: false), isNull);
    expect(ebookFinishedFlag(reachedEnd: false, hasAudio: true), isNull);
  });
}
