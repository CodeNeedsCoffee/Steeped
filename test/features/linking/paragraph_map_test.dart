import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/linking/ebook_spans.dart';

void main() {
  // 10 paragraphs: a short front page, then two chapters of very different
  // paragraph sizes (so paragraph count and word count disagree).
  final words = [5, 5, 100, 100, 100, 10, 10, 10, 10, 10];
  final map = ParagraphMap(words, [
    (title: 'One', start: 2),
    (title: 'Two', start: 5),
  ]);

  test('chapters are spans of the book by words, front matter included', () {
    expect(map.spans.map((s) => s.title), ['', 'One', 'Two']);
    expect(map.spans.first.start, 0);
    expect(map.spans.last.end, 1);
    expect(map.spans[1].start, closeTo(10 / 360, 1e-9));
    expect(map.spans[1].end, closeTo(310 / 360, 1e-9));
  });

  test('a place is counted in words, not paragraphs', () {
    // Paragraph 5 starts at word 310 of 360, though it is only 50% by paragraph.
    expect(map.wordFraction(5), closeTo(310 / 360, 1e-9));
    expect(map.wordFraction(2.5), closeTo((10 + 50) / 360, 1e-9));
  });

  test('word fraction and paragraph place convert back and forth', () {
    for (final pos in [0.0, 1.5, 2.0, 3.25, 4.99, 5.0, 7.5, 9.9]) {
      expect(map.paragraphPos(map.wordFraction(pos)), closeTo(pos, 0.02));
    }
  });

  test('a book with no chapters is one span; empty is safe', () {
    expect(ParagraphMap([3, 3], const []).spans.single.end, 1);
    final none = ParagraphMap(const [], const []);
    expect(none.spans, isEmpty);
    expect(none.wordFraction(3), 0);
    expect(none.paragraphPos(.5), 0);
  });

  test('chapters listed twice at the same start keep the last', () {
    final m = ParagraphMap(
      [10, 10, 10],
      [
        (title: 'Part', start: 0),
        (title: 'Chapter 1', start: 0),
        (title: 'Chapter 2', start: 2),
      ],
    );
    expect(m.spans.map((s) => s.title), ['Chapter 1', 'Chapter 2']);
  });
}
