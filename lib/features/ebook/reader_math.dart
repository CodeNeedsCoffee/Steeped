/// H8: pure helpers for the ebook reader: in-book search and the time-left
/// estimate. Kept free of Flutter so they are easy to test.
library;

class SearchHit {
  const SearchHit(this.index, this.snippet);

  /// Index of the paragraph that contains the match.
  final int index;
  final String snippet;
}

/// Case-insensitive search through paragraph texts: one hit per paragraph, in
/// reading order, each with a snippet around the first match. Stops at [max].
List<SearchHit> searchTexts(
  List<String> texts,
  String query, {
  int max = 100,
  int context = 40,
}) {
  final q = query.trim().toLowerCase();
  if (q.length < 2) return const [];
  final hits = <SearchHit>[];
  for (var i = 0; i < texts.length && hits.length < max; i++) {
    final text = texts[i];
    final at = text.toLowerCase().indexOf(q);
    if (at < 0) continue;
    final start = (at - context).clamp(0, text.length);
    final end = (at + q.length + context).clamp(0, text.length);
    var snippet = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (start > 0) snippet = '…$snippet';
    if (end < text.length) snippet = '$snippet…';
    hits.add(SearchHit(i, snippet));
  }
  return hits;
}

/// Rough words in a text: characters over 5.8 (an English word plus its space).
int approximateWords(int characters) => (characters / 5.8).round();

/// Average adult reading speed for non-fiction/fiction is about 230-260 wpm.
const defaultWordsPerMinute = 250;

/// Time left in the book at the current position and speed.
Duration readingTimeLeft({
  required int totalWords,
  required double fraction,
  int wordsPerMinute = defaultWordsPerMinute,
}) {
  final left = (totalWords * (1 - fraction.clamp(0.0, 1.0))).round();
  return Duration(seconds: (left / wordsPerMinute * 60).round());
}
