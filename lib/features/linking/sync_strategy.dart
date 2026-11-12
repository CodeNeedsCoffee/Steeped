/// J3: map a position in an audiobook to the matching position in its ebook
/// and back. All pure; the screens feed in chapter spans and apply the result.
library;

enum SyncConfidence { chapterMatch, overallFraction }

/// A chapter and the range it covers, in the caller's unit (seconds for audio,
/// 0..1 of the book for an ebook).
class ChapterSpan {
  const ChapterSpan(this.title, this.start, this.end);

  final String title;
  final double start;
  final double end;

  double get length => end - start;
}

class SyncResult {
  const SyncResult(this.position, this.confidence);

  /// In the target's unit.
  final double position;
  final SyncConfidence confidence;
}

/// Which strategy a switch uses. Off opens the other format at its own saved
/// position; Estimated maps by chapter title then interpolates. Precise (J6)
/// refines Estimated and falls back to it.
enum SyncMode { off, estimated, precise }

abstract class SyncStrategy {
  /// [position] is within [from]; returns the spot in [to], or null to leave
  /// the target at its own saved position.
  SyncResult? map(
    double position,
    List<ChapterSpan> from,
    List<ChapterSpan> to,
  );
}

class OffSync implements SyncStrategy {
  const OffSync();

  @override
  SyncResult? map(
    double position,
    List<ChapterSpan> from,
    List<ChapterSpan> to,
  ) => null;
}

const _words = {
  'one': '1',
  'two': '2',
  'three': '3',
  'four': '4',
  'five': '5',
  'six': '6',
  'seven': '7',
  'eight': '8',
  'nine': '9',
  'ten': '10',
  'eleven': '11',
  'twelve': '12',
  'thirteen': '13',
  'fourteen': '14',
  'fifteen': '15',
  'sixteen': '16',
  'seventeen': '17',
  'eighteen': '18',
  'nineteen': '19',
  'twenty': '20',
  'first': '1',
  'second': '2',
  'third': '3',
  'fourth': '4',
  'fifth': '5',
};

/// Lower-cased tokens with number words as digits and "chapter"/"part" noise
/// kept (they carry the number's meaning), punctuation dropped.
List<String> titleTokens(String title) => [
  for (final t in title.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
    if (t.isNotEmpty) _words[t] ?? t.replaceFirst(RegExp(r'^0+(?=\d)'), ''),
];

/// 0..1 similarity of two chapter titles (token overlap).
double titleSimilarity(String a, String b) {
  final ta = titleTokens(a).toSet(), tb = titleTokens(b).toSet();
  if (ta.isEmpty || tb.isEmpty) return 0;
  return ta.intersection(tb).length / ta.union(tb).length;
}

class EstimatedSync implements SyncStrategy {
  const EstimatedSync({this.minSimilarity = 0.6});

  final double minSimilarity;

  @override
  SyncResult? map(
    double position,
    List<ChapterSpan> from,
    List<ChapterSpan> to,
  ) {
    if (from.isEmpty || to.isEmpty) return null;
    final fromEnd = from.last.end, toEnd = to.last.end;
    if (fromEnd <= 0 || toEnd <= 0) return null;
    final pos = position.clamp(0.0, fromEnd);

    SyncResult byFraction() =>
        SyncResult(pos / fromEnd * toEnd, SyncConfidence.overallFraction);

    final source = from.lastWhere(
      (c) => c.start <= pos,
      orElse: () => from.first,
    );
    if (source.title.trim().isEmpty) return byFraction();

    ChapterSpan? best;
    var bestScore = 0.0;
    for (final c in to) {
      final s = titleSimilarity(source.title, c.title);
      if (s > bestScore) {
        best = c;
        bestScore = s;
      }
    }
    if (best == null || bestScore < minSimilarity || source.length <= 0) {
      return byFraction();
    }
    final within = ((pos - source.start) / source.length).clamp(0.0, 1.0);
    return SyncResult(
      best.start + within * best.length,
      SyncConfidence.chapterMatch,
    );
  }
}

SyncStrategy strategyFor(SyncMode mode) => switch (mode) {
  SyncMode.off => const OffSync(),
  // Precise is built in J6; until then it behaves as Estimated.
  SyncMode.estimated || SyncMode.precise => const EstimatedSync(),
};
