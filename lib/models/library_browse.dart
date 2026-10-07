import 'library_item.dart';
import 'library_series.dart';

/// PLAN (LIBRARY_PLAN.md L1): an author from `GET /api/libraries/:id/authors`
/// (`results[]`) or `GET /api/authors/:id`. `libraryItems`/`series` are only
/// present on the detail call (`include=items,series`).
class Author {
  const Author({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.numBooks,
    required this.updatedAt,
    this.books = const [],
    this.series = const [],
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    final items = (json['libraryItems'] as List<dynamic>?) ?? const [];
    final series = (json['series'] as List<dynamic>?) ?? const [];
    return Author(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      description: json['description']?.toString(),
      imagePath: json['imagePath']?.toString(),
      numBooks: (json['numBooks'] as num?)?.toInt() ?? items.length,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      books: items
          .whereType<Map<String, dynamic>>()
          .map(LibraryItem.fromJson)
          .toList(),
      series: series
          .whereType<Map<String, dynamic>>()
          .map((s) => LibrarySeries.fromJson({...s, 'books': s['items']}))
          .toList(),
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? imagePath;
  final int numBooks;
  final int updatedAt;
  final List<LibraryItem> books;
  final List<LibrarySeries> series;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}

/// A server collection (shared, admin-managed): `books[]` are full minified
/// library items.
class LibraryCollection {
  const LibraryCollection({
    required this.id,
    required this.libraryId,
    required this.name,
    required this.description,
    required this.books,
  });

  factory LibraryCollection.fromJson(Map<String, dynamic> json) {
    final books = (json['books'] as List<dynamic>?) ?? const [];
    return LibraryCollection(
      id: json['id']?.toString() ?? '',
      libraryId: json['libraryId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Collection',
      description: json['description']?.toString(),
      books: books
          .whereType<Map<String, dynamic>>()
          .map(LibraryItem.fromJson)
          .toList(),
    );
  }

  final String id;
  final String libraryId;
  final String name;
  final String? description;
  final List<LibraryItem> books;

  double get totalDuration =>
      books.fold(0.0, (sum, b) => sum + (b.duration ?? 0));
}

/// One entry of a playlist: a library item, optionally a specific podcast
/// episode of it.
class PlaylistItem {
  const PlaylistItem({
    required this.libraryItemId,
    required this.episodeId,
    required this.item,
    required this.episodeTitle,
    required this.duration,
  });

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    final li = json['libraryItem'] as Map<String, dynamic>?;
    final ep = json['episode'] as Map<String, dynamic>?;
    return PlaylistItem(
      libraryItemId: json['libraryItemId']?.toString() ?? '',
      episodeId: json['episodeId']?.toString(),
      item: li == null ? null : LibraryItem.fromJson(li),
      episodeTitle: ep?['title']?.toString(),
      duration: (ep?['duration'] as num?)?.toDouble() ??
          (li == null ? null : LibraryItem.fromJson(li).duration),
    );
  }

  final String libraryItemId;
  final String? episodeId;
  final LibraryItem? item;
  final String? episodeTitle;
  final double? duration;

  String get title => episodeTitle ?? item?.title ?? 'Unknown item';

  /// Same key shape as `LibraryItemDetail.downloadId`.
  String get downloadId =>
      episodeId == null ? libraryItemId : '$libraryItemId::$episodeId';
}

/// A per-user playlist. List responses embed full `items`.
class Playlist {
  const Playlist({
    required this.id,
    required this.libraryId,
    required this.name,
    required this.description,
    required this.items,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>?) ?? const [];
    return Playlist(
      id: json['id']?.toString() ?? '',
      libraryId: json['libraryId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Playlist',
      description: json['description']?.toString(),
      items: items
          .whereType<Map<String, dynamic>>()
          .map(PlaylistItem.fromJson)
          .toList(),
    );
  }

  final String id;
  final String libraryId;
  final String name;
  final String? description;
  final List<PlaylistItem> items;

  double get totalDuration =>
      items.fold(0.0, (sum, i) => sum + (i.duration ?? 0));

  bool contains(String libraryItemId, [String? episodeId]) => items.any(
    (i) => i.libraryItemId == libraryItemId && i.episodeId == episodeId,
  );
}
