import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/ebook/reader_math.dart';

void main() {
  const texts = [
    'The war is over.',
    'Holdfast is dead. The Eternal Flame extinguished.',
    'Nothing here.',
    'the ETERNAL flame again',
  ];

  test('finds paragraphs case-insensitively, in order, one hit each', () {
    final hits = searchTexts(texts, 'eternal flame');
    expect([for (final h in hits) h.index], [1, 3]);
  });

  test('a snippet surrounds the match and marks cut ends', () {
    final long = '${'a ' * 60}needle${' b' * 60}';
    final hit = searchTexts([long], 'needle').single;
    expect(hit.snippet, contains('needle'));
    expect(hit.snippet.startsWith('…'), isTrue);
    expect(hit.snippet.endsWith('…'), isTrue);
    expect(hit.snippet.length, lessThan(120));
  });

  test('very short queries and no matches return nothing', () {
    expect(searchTexts(texts, 'a'), isEmpty);
    expect(searchTexts(texts, 'zebra'), isEmpty);
  });

  test('results are capped', () {
    final many = List.generate(500, (i) => 'match $i');
    expect(searchTexts(many, 'match', max: 50), hasLength(50));
  });

  test('time left shrinks as you read', () {
    final start = readingTimeLeft(totalWords: 100000, fraction: 0);
    final half = readingTimeLeft(totalWords: 100000, fraction: 0.5);
    expect(start, const Duration(minutes: 400));
    expect(half, const Duration(minutes: 200));
    expect(readingTimeLeft(totalWords: 100000, fraction: 1), Duration.zero);
  });

  test('a faster reader finishes sooner; fraction is clamped', () {
    expect(
      readingTimeLeft(totalWords: 1000, fraction: 0, wordsPerMinute: 500),
      const Duration(minutes: 2),
    );
    expect(readingTimeLeft(totalWords: 1000, fraction: 2), Duration.zero);
  });

  test('approximate words', () {
    expect(approximateWords(5800), 1000);
  });
}
