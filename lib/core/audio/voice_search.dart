/// QOL_PLAN F5: picks which book "play <something>" means.
class VoiceCandidate {
  const VoiceCandidate({required this.id, required this.title, this.author});

  final String id;
  final String title;
  final String? author;
}

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Strips spoken filler ("play the audiobook ...", "... by ...") to leave
/// the words that identify a book.
String cleanVoiceQuery(String raw) {
  var q = _normalize(raw);
  q = q.replaceFirst(
    RegExp(r'^(please )?(play|listen to|read|resume|continue)( me)?( the)?( audio ?book| book)?( called| named| titled)?( |$)'),
    '',
  );
  q = q.replaceFirst(RegExp(r'^the '), '').trim();
  // "play audiobooks" / "play my books" name no book: resume instead.
  const generic = {'audiobook', 'audiobooks', 'book', 'books', 'my audiobooks', 'my books', 'something'};
  return generic.contains(q) ? '' : q;
}

/// Best match for [rawQuery], or null if nothing is a plausible hit.
/// Exact title beats title-contains beats query-contains-title beats an
/// author-name hit; ties keep the earlier (server-ranked) candidate.
String? pickVoiceMatch(String rawQuery, List<VoiceCandidate> candidates) {
  final q = cleanVoiceQuery(rawQuery);
  if (q.isEmpty) return null;
  // "<title> by <author>": match the title part, let the author break ties.
  final byIdx = q.indexOf(' by ');
  final titlePart = byIdx > 0 ? q.substring(0, byIdx) : q;
  final authorPart = byIdx > 0 ? q.substring(byIdx + 4) : null;

  String? best;
  var bestScore = 0;
  for (final c in candidates) {
    final title = _normalize(c.title);
    final author = _normalize(c.author ?? '');
    var score = 0;
    if (title == titlePart) {
      score = 100;
    } else if (title.contains(titlePart) && titlePart.length >= 3) {
      score = 70;
    } else if (titlePart.contains(title) && title.length >= 3) {
      score = 50;
    } else if (author.isNotEmpty && author.contains(q)) {
      score = 30;
    }
    if (score > 0 && authorPart != null && author.contains(authorPart)) {
      score += 10;
    }
    if (score > bestScore) {
      bestScore = score;
      best = c.id;
    }
  }
  return best;
}
