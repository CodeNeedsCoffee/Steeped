import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/ebook/data/reading_position.dart';

EbookHighlight h(int p, String t) =>
    EbookHighlight(paragraph: p, text: t, createdAt: DateTime(2026));

void main() {
  test('the same word highlighted twice is kept once', () {
    final out = mergeHighlights([h(3, 'word')], [h(3, 'word')]);
    expect(out.length, 1);
  });

  test('a highlight inside an existing one is dropped', () {
    expect(mergeHighlights([h(3, 'a long phrase')], [h(3, 'long')]).length, 1);
  });

  test('extending a highlight replaces the shorter one', () {
    final out = mergeHighlights([h(3, 'long')], [h(3, 'a long phrase')]);
    expect(out.map((x) => x.text), ['a long phrase']);
  });

  test('the same text in another paragraph is a different highlight', () {
    expect(mergeHighlights([h(3, 'word')], [h(4, 'word')]).length, 2);
  });

  test('renaming a bookmark keeps its place', () {
    final b = EbookBookmark(
      location: 'c',
      fraction: .4,
      label: 'old',
      createdAt: DateTime(2026),
    ).withLabel('new');
    expect((b.label, b.fraction, b.location), ('new', .4, 'c'));
  });
}
