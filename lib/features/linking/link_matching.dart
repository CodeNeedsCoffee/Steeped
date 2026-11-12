/// J1: decide whether an audiobook item and an ebook item are the same book.
/// The server has no link between separate items, so match on ASIN, then ISBN,
/// then normalised author + title (series and sequence as tie-breakers).
library;

enum LinkReason { asin, isbn, authorTitle }

/// The fields of an item that matching reads.
class LinkKey {
  const LinkKey({
    required this.id,
    required this.title,
    this.author,
    this.asin,
    this.isbn,
    this.seriesName,
    this.seriesSequence,
  });

  final String id;
  final String title;
  final String? author;
  final String? asin;
  final String? isbn;
  final String? seriesName;
  final String? seriesSequence;
}

class LinkCandidate {
  const LinkCandidate(this.key, this.reason);

  final LinkKey key;
  final LinkReason reason;
}

/// Lower-case, strip punctuation, a leading article and a trailing subtitle
/// marker so "The Hobbit: Or There and Back Again" and "Hobbit" line up.
String normalizeTitle(String value) {
  var s = value.toLowerCase();
  s = s.replaceAll(RegExp(r'\((?:unabridged|abridged)\)'), ' ');
  s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceFirst(RegExp(r'^(the|a|an) '), '');
  return s;
}

String _normalizeId(String? v) =>
    (v ?? '').toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

/// The title before a subtitle ("Alchemised: A Novel" -> "alchemised").
String mainTitle(String value) =>
    normalizeTitle(value.split(RegExp(r'\s[-–—]\s|:')).first);

/// Authors compare as a set of names with spaces and punctuation removed, so
/// "A, B" equals "B, A" and "Sen Lin Yu" equals "SenLinYu".
Set<String> _authors(String? v) => {
  for (final part in (v ?? '').split(RegExp(r',|&|;| and ')))
    if (normalizeTitle(part).replaceAll(' ', '').isNotEmpty)
      normalizeTitle(part).replaceAll(' ', ''),
};

/// Why [a] and [b] are the same book, or null when they are not.
LinkReason? matchReason(LinkKey a, LinkKey b) {
  final aa = _normalizeId(a.asin), ba = _normalizeId(b.asin);
  if (aa.isNotEmpty && aa == ba) return LinkReason.asin;
  final ai = _normalizeId(a.isbn), bi = _normalizeId(b.isbn);
  if (ai.isNotEmpty && ai == bi) return LinkReason.isbn;

  final at = mainTitle(a.title), bt = mainTitle(b.title);
  if (at.isEmpty || at != bt) return null;
  final au = _authors(a.author), bu = _authors(b.author);
  if (au.isEmpty || bu.isEmpty || au.intersection(bu).isEmpty) return null;
  // Two entries of one series can share a title; the sequence settles it.
  final as = a.seriesSequence, bs = b.seriesSequence;
  if (as != null && bs != null && as != bs) return null;
  return LinkReason.authorTitle;
}

/// [candidates] that match [source], best reason first (ASIN, ISBN, then
/// author + title). The source itself is never returned.
List<LinkCandidate> findLinkCandidates(
  LinkKey source,
  Iterable<LinkKey> candidates,
) {
  final out = <LinkCandidate>[
    for (final c in candidates)
      if (c.id != source.id)
        if (matchReason(source, c) case final r?) LinkCandidate(c, r),
  ];
  out.sort((x, y) => x.reason.index.compareTo(y.reason.index));
  return out;
}
