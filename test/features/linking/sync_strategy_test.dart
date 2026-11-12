import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/linking/sync_strategy.dart';

void main() {
  const audio = [
    ChapterSpan('Opening Credits', 0, 60),
    ChapterSpan('Chapter 1', 60, 660),
    ChapterSpan('Chapter 2', 660, 1260),
    ChapterSpan('Chapter 3', 1260, 1860),
  ];
  const ebook = [
    ChapterSpan('Cover', 0, 0.02),
    ChapterSpan('Chapter One', 0.02, 0.40),
    ChapterSpan('Chapter Two', 0.40, 0.70),
    ChapterSpan('Chapter Three', 0.70, 1.0),
  ];
  const strategy = EstimatedSync();

  test('number words match digits and interpolate inside the chapter', () {
    final r = strategy.map(360, audio, ebook)!; // halfway through Chapter 1
    expect(r.confidence, SyncConfidence.chapterMatch);
    expect(r.position, closeTo(0.02 + 0.5 * 0.38, 1e-9));
  });

  test('ebook to audio goes the other way', () {
    final r = strategy.map(0.55, ebook, audio)!; // half of Chapter Two
    expect(r.confidence, SyncConfidence.chapterMatch);
    expect(r.position, closeTo(660 + 0.5 * 600, 1e-6));
  });

  test('unmatched titles fall back to the overall fraction', () {
    const odd = [
      ChapterSpan('Prologue', 0, 100),
      ChapterSpan('Aftermath', 100, 200),
    ];
    final r = strategy.map(50, odd, ebook)!;
    expect(r.confidence, SyncConfidence.overallFraction);
    expect(r.position, closeTo(0.25, 1e-9));
  });

  test('no chapters on one side returns null (open at own position)', () {
    expect(strategy.map(10, const [], ebook), isNull);
    expect(strategy.map(10, audio, const []), isNull);
  });

  test('position past the end clamps', () {
    final r = strategy.map(99999, audio, ebook)!;
    expect(r.position, closeTo(1.0, 1e-9));
  });

  test('Off never maps', () {
    expect(strategyFor(SyncMode.off).map(10, audio, ebook), isNull);
    expect(strategyFor(SyncMode.estimated), isA<EstimatedSync>());
  });

  test('Chapter 1 does not match Chapter 10 style titles', () {
    expect(titleSimilarity('Chapter 1', 'Chapter 10'), lessThan(0.6));
  });
}
