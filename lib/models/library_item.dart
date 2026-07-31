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
}
