/// PLAN.md J6 (Precise sync): matching what the speech recogniser heard against
/// the book's text, in both directions. Pure functions; the recogniser itself
/// is behind [Transcribe] so this can be tested without a phone.

/// Lower-case words of [text] with punctuation and apostrophes dropped.
List<String> speechWords(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r"['’]"), '')
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.isNotEmpty)
    .toList();

// Short words ("a", "the") match everywhere, so they count for less.
double _weight(String w) => w.length >= 4 ? 1.0 : 0.3;

/// Where in [hay] the words [needle] best appear: the index of the first word
/// of the best-matching stretch, and its score from 0 to 1 (the share of the
/// needle's weight found in a stretch about 1.5x its length, order ignored so
/// a missed or doubled word does not matter). Ties go to the stretch nearest
/// [prefer]. Null when either list is empty.
({int index, double score})? locateWords(
  List<String> hay,
  List<String> needle, {
  int prefer = 0,
}) {
  if (hay.isEmpty || needle.isEmpty) return null;
  final want = <String, double>{};
  var total = 0.0;
  for (final w in needle) {
    want[w] = (want[w] ?? 0) + _weight(w);
    total += _weight(w);
  }
  final len = (needle.length * 1.5).ceil().clamp(1, hay.length);
  final have = <String, int>{};
  final need = <String, int>{};
  for (final w in needle) {
    need[w] = (need[w] ?? 0) + 1;
  }
  var matched = 0.0;
  void add(String w) {
    final n = need[w];
    if (n == null) return;
    final h = have[w] ?? 0;
    if (h < n) matched += _weight(w);
    have[w] = h + 1;
  }

  void remove(String w) {
    final n = need[w];
    if (n == null) return;
    final h = have[w]! - 1;
    have[w] = h;
    if (h < n) matched -= _weight(w);
  }

  for (var i = 0; i < len; i++) {
    add(hay[i]);
  }
  var bestIndex = 0;
  var bestScore = -1.0;
  for (var i = 0; ; i++) {
    final score = matched / total - 0.00001 * (i - prefer).abs();
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
    if (i + len >= hay.length) break;
    remove(hay[i]);
    add(hay[i + len]);
  }
  // Start at the first word in the stretch that is one of the needle's own
  // first words, so the index points at where the passage begins.
  final head = needle.take(3).where((w) => w.length >= 4).toSet();
  var start = bestIndex;
  for (var i = bestIndex; i < bestIndex + len && i < hay.length; i++) {
    if (head.contains(hay[i])) {
      start = i;
      break;
    }
  }
  return (index: start, score: bestScore.clamp(0.0, 1.0));
}

/// Transcribes [durSec] seconds of the audiobook from [startSec]; null when
/// recognition is unavailable or failed.
typedef Transcribe = Future<String?> Function(double startSec, double durSec);

/// The audiobook time at which the words [target] (what is on the reader's
/// screen) are spoken, searching windows of [window] seconds around
/// [estimate] (the Estimated guess), nearest first. Null when nothing matches
/// well enough, so the caller keeps its estimate.
Future<({double seconds, double score})?> findAudioSeconds({
  required Transcribe transcribe,
  required double estimate,
  required List<String> target,
  required double totalSeconds,
  double window = 40,
  double step = 30,
  int maxProbes = 7,
  double accept = 0.55,
  double good = 0.8,
}) async {
  if (target.length < 5) return null;
  ({double seconds, double score})? best;
  // 0, +1, -1, +2, -2 ... steps from the estimate.
  for (var probe = 0; probe < maxProbes; probe++) {
    final k = probe == 0 ? 0 : (probe.isOdd ? (probe + 1) ~/ 2 : -(probe ~/ 2));
    final start = (estimate + k * step - window / 2).clamp(
      0.0,
      (totalSeconds - window).clamp(0.0, double.infinity),
    );
    final text = await transcribe(start, window);
    if (text == null) return best;
    final words = speechWords(text);
    final loc = locateWords(words, target);
    if (loc == null) continue;
    if (best == null || loc.score > best.score) {
      best = (
        seconds: start + loc.index / words.length * window,
        score: loc.score,
      );
    }
    if (loc.score >= good) break;
  }
  return best != null && best.score >= accept ? best : null;
}

/// The paragraph where the audiobook, [seconds] in, is reading: transcribes a
/// short clip there and finds its first words among [paragraphs] near
/// [estimateIndex]. [within] is how far into the paragraph (0..1).
Future<({int paragraph, double within, double score})?> findParagraph({
  required Transcribe transcribe,
  required double seconds,
  required List<String> paragraphs,
  required int estimateIndex,
  double clip = 25,
  int radius = 250,
  double accept = 0.55,
}) async {
  final text = await transcribe(seconds, clip);
  if (text == null) return null;
  final heard = speechWords(text);
  if (heard.length < 6) return null;
  final needle = heard.take(18).toList();
  final from = (estimateIndex - radius).clamp(0, paragraphs.length);
  final to = (estimateIndex + radius).clamp(0, paragraphs.length);
  final hay = <String>[];
  final owner = <int>[];
  final firstWord = <int>[];
  for (var p = from; p < to; p++) {
    firstWord.add(hay.length);
    for (final w in speechWords(paragraphs[p])) {
      hay.add(w);
      owner.add(p);
    }
  }
  final prefer =
      estimateIndex - from < firstWord.length && estimateIndex >= from
      ? firstWord[estimateIndex - from]
      : 0;
  final loc = locateWords(hay, needle, prefer: prefer);
  if (loc == null || loc.score < accept) return null;
  final paragraph = owner[loc.index];
  final startOfParagraph = firstWord[paragraph - from];
  final count = speechWords(paragraphs[paragraph]).length;
  return (
    paragraph: paragraph,
    within: count == 0
        ? 0.0
        : ((loc.index - startOfParagraph) / count).clamp(0.0, 0.95),
    score: loc.score,
  );
}
