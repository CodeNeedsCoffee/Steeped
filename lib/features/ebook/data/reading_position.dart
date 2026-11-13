/// A saved place in a book: [location] in the same format the server stores
/// (EPUB CFI, or a 1-based page number for PDF/comics, matching the official
/// apps), [fraction] 0..1 through the book, and when it was recorded so the
/// newer of the local and server positions wins.
class ReadingPosition {
  const ReadingPosition({
    required this.location,
    required this.fraction,
    required this.updatedAt,
  });

  factory ReadingPosition.fromJson(Map<String, dynamic> json) {
    return ReadingPosition(
      location: json['location'] as String? ?? '',
      fraction: (json['fraction'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final String location;
  final double fraction;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'location': location,
    'fraction': fraction,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
}

/// A device-local bookmark. [location] is a CFI or page number as above.
class EbookBookmark {
  const EbookBookmark({
    required this.location,
    required this.fraction,
    required this.label,
    required this.createdAt,
  });

  factory EbookBookmark.fromJson(Map<String, dynamic> json) {
    return EbookBookmark(
      location: json['location'] as String? ?? '',
      fraction: (json['fraction'] as num?)?.toDouble() ?? 0,
      label: json['label'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final String location;
  final double fraction;
  final String label;
  final DateTime createdAt;

  EbookBookmark withLabel(String label) => EbookBookmark(
    location: location,
    fraction: fraction,
    label: label,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'location': location,
    'fraction': fraction,
    'label': label,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };
}

/// A device-local text highlight in an EPUB: the selected [text] and the
/// absolute paragraph index it was found in (stable for a given file).
class EbookHighlight {
  const EbookHighlight({
    required this.paragraph,
    required this.text,
    required this.createdAt,
  });

  factory EbookHighlight.fromJson(Map<String, dynamic> json) {
    return EbookHighlight(
      paragraph: (json['paragraph'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final int paragraph;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'paragraph': paragraph,
    'text': text,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };
}

/// [existing] plus [added], without repeating a highlight. A new highlight
/// that sits inside one already in the same paragraph is dropped; one that
/// swallows existing ones replaces them (so extending a highlight works).
List<EbookHighlight> mergeHighlights(
  List<EbookHighlight> existing,
  List<EbookHighlight> added,
) {
  final out = [...existing];
  for (final h in added) {
    final same = out.where((x) => x.paragraph == h.paragraph);
    if (same.any((x) => x.text.contains(h.text))) continue;
    out.removeWhere(
      (x) => x.paragraph == h.paragraph && h.text.contains(x.text),
    );
    out.add(h);
  }
  return out;
}
