import 'dart:math' as math;

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

// The recogniser mishears endings and names ("Paladin" for "Paladia", "corporation"
// for "cooperating"), so words of five letters or more match on their first
// four letters.
String _key(String w) => w.length >= 5 ? w.substring(0, 4) : w;

// Short words ("a", "the") match everywhere, so they count for less.
double _weight(String key) => key.length >= 4 ? 1.0 : 0.3;

/// Where a set of words sits in a longer list, and how sure that is.
class Located {
  const Located(this.index, this.score, this.run, this.margin);

  /// Index (in the hay list) of the first word of the best-matching stretch.
  final int index;

  /// Share of the needle's weight found in that stretch, 0..1.
  final double score;

  /// The longest run of needle words that appear in the stretch one after the
  /// other (a real passage, not scattered common words).
  final int run;

  /// How much better this stretch scores than the best stretch elsewhere
  /// (0 when the passage is repeated, near 1 when it is unique).
  final double margin;
}

/// Where in the key list [keys] (words already reduced with [_key]) the words
/// [needle] best appear, between [lo] and [hi]. A stretch is about 1.5x the
/// needle's length, order ignored for the score so a missed or doubled word
/// does not matter; each distinct needle word counts once (the recogniser
/// repeats a phrase while it revises it, the book does not). Ties go to the
/// stretch nearest [prefer]. [weight] says how much a word is worth (rare
/// words are worth more than common ones).
Located? _locate(
  List<String> keys,
  int lo,
  int hi,
  List<String> needle, {
  int prefer = 0,
  double Function(String key) weight = _weight,
}) {
  if (hi <= lo || needle.isEmpty) return null;
  final needleKeys = [for (final w in needle) _key(w)];
  final want = <String>{...needleKeys};
  var total = 0.0;
  for (final k in want) {
    total += weight(k);
  }
  if (total <= 0) return null;
  final span = hi - lo;
  final len = (needle.length * 1.5).ceil().clamp(1, span);
  final have = <String, int>{};
  var matched = 0.0;
  void add(String k) {
    if (!want.contains(k)) return;
    final h = have[k] ?? 0;
    if (h == 0) matched += weight(k);
    have[k] = h + 1;
  }

  void remove(String k) {
    if (!want.contains(k)) return;
    final h = have[k]! - 1;
    have[k] = h;
    if (h == 0) matched -= weight(k);
  }

  for (var i = 0; i < len; i++) {
    add(keys[lo + i]);
  }
  final scores = <double>[];
  for (var i = 0; ; i++) {
    scores.add(matched / total);
    if (i + len >= span) break;
    remove(keys[lo + i]);
    add(keys[lo + i + len]);
  }
  var best = 0;
  var bestValue = -1.0;
  for (var i = 0; i < scores.length; i++) {
    final v = scores[i] - 0.00001 * ((lo + i) - prefer).abs();
    if (v > bestValue) {
      bestValue = v;
      best = i;
    }
  }
  var second = 0.0;
  for (var i = 0; i < scores.length; i++) {
    if ((i - best).abs() > len && scores[i] > second) second = scores[i];
  }
  // The longest run of needle words in order inside the best stretch.
  var run = 0;
  var prev = List<int>.filled(needleKeys.length + 1, 0);
  for (var i = 0; i < len; i++) {
    final cur = List<int>.filled(needleKeys.length + 1, 0);
    for (var j = 0; j < needleKeys.length; j++) {
      if (keys[lo + best + i] == needleKeys[j]) {
        cur[j + 1] = prev[j] + 1;
        if (cur[j + 1] > run) run = cur[j + 1];
      }
    }
    prev = cur;
  }
  // Start at the first word in the stretch that is one of the needle's own
  // first words, so the index points at where the passage begins.
  final head = {
    for (final w in needle.take(6).where((w) => w.length >= 4)) _key(w),
  };
  var start = lo + best;
  for (var i = lo + best; i < lo + best + len && i < hi; i++) {
    if (head.contains(keys[i])) {
      start = i;
      break;
    }
  }
  final score = scores[best].clamp(0.0, 1.0);
  return Located(start, score, run, (score - second).clamp(0.0, 1.0));
}

/// Where in [hay] the words [needle] best appear (see [_locate]); [prefer] is
/// the index to favour on ties. Null when either list is empty.
Located? locateWords(List<String> hay, List<String> needle, {int prefer = 0}) =>
    _locate(
      [for (final w in hay) _key(w)],
      0,
      hay.length,
      needle,
      prefer: prefer,
    );

/// A book's words in one list, with where each paragraph starts and how common
/// each word is across the book (so a rare word, like a name, counts for more
/// than "the"). Build it once per book and reuse it for every listen.
class BookIndex {
  BookIndex(List<String> paragraphs) {
    for (var p = 0; p < paragraphs.length; p++) {
      first.add(keys.length);
      for (final w in speechWords(paragraphs[p])) {
        final k = _key(w);
        keys.add(k);
        owner.add(p);
        count[k] = (count[k] ?? 0) + 1;
      }
    }
    first.add(keys.length);
    _paragraphs = paragraphs.length;
  }

  final keys = <String>[];
  final owner = <int>[];
  final first = <int>[];
  final count = <String, int>{};
  late final int _paragraphs;

  int get paragraphCount => _paragraphs;

  /// Worth of a word: high for rare, low for words found all over the book.
  double weight(String key) {
    final c = count[key] ?? 0;
    final idf = math.log((keys.length + 1) / (c + 1));
    // Scale to about 0.2 (very common) .. 1.6 (rare), then the usual
    // discount for very short words.
    final w = (idf / 4).clamp(0.2, 1.6);
    return key.length >= 4 ? w : w * 0.5;
  }

  /// Words in front of paragraph [p].
  int wordsBefore(int p) => first[p.clamp(0, _paragraphs)];

  int wordsIn(int p) => first[p + 1] - first[p];
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
  double window = 60,
  double step = 50,
  int maxProbes = 9,
  void Function(int probe, int total)? onProbe,
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
    onProbe?.call(probe + 1, maxProbes);
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

/// A streaming [Transcribe]: it calls [enough] with the transcript so far and
/// how many seconds of audio that covers, as the recogniser works through the
/// clip, and stops as soon as [enough] returns true. Returns the transcript at
/// that point.
typedef Listen =
    Future<String?> Function(
      double startSec,
      double maxSec,
      bool Function(String text, double audioSec) enough,
    );

/// Whether a match is trustworthy after hearing [audioSec] seconds. Less audio
/// means fewer words, so a short clip must match harder: a high score, a run
/// of words in order, and a clear gap to the runner-up. The full clip only has
/// to clear [accept] with a short run.
bool _confident(Located l, double audioSec, double accept) {
  if (audioSec < 8) return l.score >= 0.8 && l.run >= 4 && l.margin >= 0.25;
  if (audioSec < 16) return l.score >= 0.7 && l.run >= 3 && l.margin >= 0.2;
  return l.score >= accept && l.run >= 2;
}

/// The paragraph where the audiobook, [seconds] in, is reading: listens to a
/// short clip there and finds its words anywhere in the book ([paragraphs],
/// preferring the neighbourhood of [estimateIndex] on ties). With [listen] the
/// clip is judged as it arrives, at about 5, 10, 18 and 26 seconds, and the
/// listen stops at the first confident match; with only [transcribe] the whole
/// clip is judged once. [within] is how far into the paragraph (0..1).
/// [index] can be passed in to avoid rebuilding the book's word list.
Future<({int paragraph, double within, double score, double heardSeconds})?>
findParagraph({
  Transcribe? transcribe,
  Listen? listen,
  required double seconds,
  required List<String> paragraphs,
  required int estimateIndex,
  BookIndex? index,
  double clip = 25,
  double accept = 0.55,
}) async {
  assert(transcribe != null || listen != null);
  final book = index ?? BookIndex(paragraphs);
  final prefer = book.wordsBefore(estimateIndex);
  Located? locate(String text) {
    final heard = speechWords(text);
    if (heard.length < 6) return null;
    return _locate(
      book.keys,
      0,
      book.keys.length,
      heard.take(70).toList(),
      prefer: prefer,
      weight: book.weight,
    );
  }

  String? text;
  Located? early;
  var heardSeconds = clip;
  if (listen != null) {
    var nextCheck = 5.0;
    text = await listen(seconds, clip, (t, audioSec) {
      if (audioSec < nextCheck) return false;
      while (nextCheck <= audioSec) {
        nextCheck += nextCheck < 10 ? 5 : 8;
      }
      if (speechWords(t).length < 8) return false;
      final l = locate(t);
      if (l != null && _confident(l, audioSec, accept)) {
        early = l;
        heardSeconds = audioSec;
        return true;
      }
      return false;
    });
  } else {
    text = await transcribe!(seconds, clip);
  }
  if (text == null) return null;
  final loc = early ?? locate(text);
  if (loc == null ||
      !_confident(loc, early == null ? clip : heardSeconds, accept)) {
    return null;
  }
  final paragraph = book.owner[loc.index];
  final count = book.wordsIn(paragraph);
  return (
    paragraph: paragraph,
    within: count == 0
        ? 0.0
        : ((loc.index - book.wordsBefore(paragraph)) / count).clamp(0.0, 0.95),
    score: loc.score,
    heardSeconds: heardSeconds,
  );
}

/// Narration speed used to turn a distance in words into seconds (about 155
/// words a minute at normal speed).
const narrationWordsPerSecond = 2.6;

/// The estimate-then-listen search (ebook -> audio), for when the percentage
/// guess [estimate] may be many minutes out. It converges like a bisection:
/// listen for 25 s at the current guess and find which paragraph the narrator
/// is really on (anywhere in the book); the words between that paragraph and
/// the reader's place ([position]: paragraph index plus how far into it)
/// become a time offset at the narration speed; jump by it and listen again,
/// stopping when the two are within about 20 seconds of each other. From the
/// second round on the speed is measured from the last two listens, so a
/// narrator who is faster or slower than average is corrected for.
///
/// Falls back to the plain window scan when the first listen finds nothing.
/// Null when it never converges to a listen that matched.
Future<({double seconds, double score})?> findAudioSecondsGuided({
  required Transcribe transcribe,
  required double estimate,
  required List<String> paragraphs,
  required double position,
  required List<String> target,
  required double totalSeconds,
  int maxRounds = 4,
  BookIndex? index,
  Listen? listen,
  void Function(int step, int of)? onStep,
}) async {
  // A place in the book as one number: words in front of it.
  final book = index ?? BookIndex(paragraphs);
  double wordsAt(double place) {
    final p = place.floor().clamp(0, paragraphs.length - 1);
    return book.wordsBefore(p) + book.wordsIn(p) * (place - p).clamp(0.0, 1.0);
  }

  final goal = wordsAt(position);
  var t = estimate.clamp(0.0, totalSeconds);
  double? prevT;
  double? prevWords;
  var rate = narrationWordsPerSecond;
  ({double seconds, double score})? best;
  for (var round = 1; round <= maxRounds; round++) {
    onStep?.call(round, maxRounds);
    final here = await findParagraph(
      transcribe: transcribe,
      listen: listen,
      seconds: t,
      paragraphs: paragraphs,
      estimateIndex: position.floor(),
      index: book,
    );
    if (here == null) {
      if (round == 1) {
        return findAudioSeconds(
          transcribe: transcribe,
          estimate: estimate,
          target: target,
          totalSeconds: totalSeconds,
          maxProbes: maxRounds - 1,
          onProbe: (n, of) => onStep?.call(round + n, maxRounds),
        );
      }
      break;
    }
    final heard = wordsAt(here.paragraph + here.within);
    final gap = goal - heard; // words still to go (negative: overshot)
    if (prevT != null && prevWords != null && (t - prevT).abs() > 30) {
      final measured = (heard - prevWords) / (t - prevT);
      if (measured > 0) rate = measured.clamp(1.8, 3.4);
    }
    prevT = t;
    prevWords = heard;
    final next = (t + gap / rate).clamp(0.0, totalSeconds);
    best = (seconds: next, score: here.score);
    // Close enough: the narrator was within ~20 s of the reader's place.
    if (gap.abs() / rate < 20) break;
    t = next;
  }
  return best;
}
