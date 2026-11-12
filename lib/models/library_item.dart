/// A single entry from `GET /api/libraries/:id/items` (`results[]`) or a
/// `type: 'book'|'episode'|'podcast'` personalized shelf's `entities[]`.
/// Server shape is `LibraryItemMinified` (book or podcast media) — see
/// `~/Code/audiobookshelf/server/models/{LibraryItem,Book,Podcast}.js`
/// (`toOldJSONMinified`). Book and podcast fields are flattened into one
/// class here since card UI (shelf/grid) only needs title/author/cover/
/// duration regardless of media type — full book detail lives in
/// [LibraryItemDetail].
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.mediaType,
    required this.coverPath,
    required this.updatedAt,
    required this.title,
    required this.subtitle,
    required this.authorOrPublisherName,
    required this.seriesName,
    required this.duration,
    required this.hasEbook,
    this.hasAudio = true,
    this.asin,
    this.isbn,
    this.libraryId,
    this.seriesSequence,
    this.collapsedSeries,
  });

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    final mediaType = json['mediaType'] as String? ?? 'book';
    final media = (json['media'] as Map<String, dynamic>?) ?? const {};
    final metadata = (media['metadata'] as Map<String, dynamic>?) ?? const {};

    final isPodcast = mediaType == 'podcast';
    return LibraryItem(
      id: json['id'] as String,
      mediaType: mediaType,
      coverPath: media['coverPath'] as String?,
      updatedAt: json['updatedAt'] as int? ?? 0,
      title: metadata['title'] as String? ?? 'Untitled',
      subtitle: isPodcast ? null : metadata['subtitle'] as String?,
      authorOrPublisherName:
          (isPodcast ? metadata['author'] : metadata['authorName'])
              as String?,
      seriesName: isPodcast ? null : metadata['seriesName'] as String?,
      duration: isPodcast
          ? null
          : (media['duration'] as num?)?.toDouble(),
      hasEbook: !isPodcast && media['ebookFormat'] != null,
      // Absent on older servers/shapes: assume audio so Play is never hidden by mistake.
      hasAudio: isPodcast || ((media['numAudioFiles'] as num?) ?? 1) > 0,
      asin: isPodcast ? null : metadata['asin']?.toString(),
      isbn: isPodcast ? null : metadata['isbn']?.toString(),
      libraryId: json['libraryId']?.toString(),
      // Only present when the item came from an author page's series group.
      seriesSequence: metadata['series'] is Map<String, dynamic>
          ? (metadata['series'] as Map<String, dynamic>)['sequence']
                ?.toString()
          : null,
      collapsedSeries: json['collapsedSeries'] is Map<String, dynamic>
          ? CollapsedSeries.fromJson(
              json['collapsedSeries'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String id;
  final String mediaType; // 'book' | 'podcast'
  final String? coverPath;
  final int updatedAt;
  final String title;
  final String? subtitle;
  final String? authorOrPublisherName;
  final String? seriesName;
  final double? duration; // seconds, books only in this minified shape
  final bool hasEbook;

  /// False for ebook-only items, which have nothing to play.
  final bool hasAudio;

  /// Identifiers used to link an ebook item to its audiobook item.
  final String? asin;
  final String? isbn;
  final String? libraryId;

  /// Position within the series this item was grouped under (author pages).
  final String? seriesSequence;

  /// Set when the library list was fetched with `collapseseries`: this item
  /// stands in for a whole series.
  final CollapsedSeries? collapsedSeries;
}

class CollapsedSeries {
  const CollapsedSeries({
    required this.id,
    required this.name,
    required this.numBooks,
  });

  factory CollapsedSeries.fromJson(Map<String, dynamic> json) {
    return CollapsedSeries(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Series',
      numBooks: (json['numBooks'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final int numBooks;
}
