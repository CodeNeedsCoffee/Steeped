import 'media_progress.dart';

class AuthorRef {
  const AuthorRef({required this.id, required this.name});

  factory AuthorRef.fromJson(Map<String, dynamic> json) {
    return AuthorRef(id: json['id'] as String, name: json['name'] as String);
  }

  final String id;
  final String name;
}

class SeriesRef {
  const SeriesRef({required this.id, required this.name, this.sequence});

  factory SeriesRef.fromJson(Map<String, dynamic> json) {
    return SeriesRef(
      id: json['id'] as String,
      name: json['name'] as String,
      sequence: json['sequence'] as String?,
    );
  }

  final String id;
  final String name;
  final String? sequence;

  String get label => sequence == null ? name : '$name #$sequence';
}

class BookChapter {
  const BookChapter({
    required this.title,
    required this.start,
    required this.end,
  });

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      title: json['title'] as String? ?? '',
      start: (json['start'] as num?)?.toDouble() ?? 0,
      end: (json['end'] as num?)?.toDouble() ?? 0,
    );
  }

  final String title;
  final double start;
  final double end;
}

/// `GET /api/items/:id?expanded=1&include=progress` — see
/// `~/Code/audiobookshelf/server/models/{LibraryItem,Book}.js`
/// (`toOldJSONExpanded`). Podcast items are only minimally populated here
/// (title/cover/description) — full podcast browsing is Milestone 2 /
/// Phase 7, not this pass.
class LibraryItemDetail {
  const LibraryItemDetail({
    required this.id,
    required this.mediaType,
    required this.coverPath,
    required this.updatedAt,
    required this.title,
    required this.subtitle,
    required this.authors,
    required this.narrators,
    required this.series,
    required this.genres,
    required this.description,
    required this.publishedYear,
    required this.duration,
    required this.chapters,
    required this.hasEbook,
    required this.progress,
  });

  factory LibraryItemDetail.fromJson(Map<String, dynamic> json) {
    final mediaType = json['mediaType'] as String? ?? 'book';
    final media = (json['media'] as Map<String, dynamic>?) ?? const {};
    final metadata = (media['metadata'] as Map<String, dynamic>?) ?? const {};
    final isPodcast = mediaType == 'podcast';

    final progressJson = json['userMediaProgress'] as Map<String, dynamic>?;

    if (isPodcast) {
      return LibraryItemDetail(
        id: json['id'] as String,
        mediaType: mediaType,
        coverPath: media['coverPath'] as String?,
        updatedAt: json['updatedAt'] as int? ?? 0,
        title: metadata['title'] as String? ?? 'Untitled',
        subtitle: null,
        authors: metadata['author'] != null
            ? [AuthorRef(id: '', name: metadata['author'] as String)]
            : const [],
        narrators: const [],
        series: const [],
        genres:
            (metadata['genres'] as List<dynamic>?)?.cast<String>() ??
            const [],
        description: metadata['description'] as String?,
        publishedYear: null,
        duration: null,
        chapters: const [],
        hasEbook: false,
        progress: progressJson == null
            ? null
            : MediaProgress.fromJson(progressJson),
      );
    }

    return LibraryItemDetail(
      id: json['id'] as String,
      mediaType: mediaType,
      coverPath: media['coverPath'] as String?,
      updatedAt: json['updatedAt'] as int? ?? 0,
      title: metadata['title'] as String? ?? 'Untitled',
      subtitle: metadata['subtitle'] as String?,
      authors:
          (metadata['authors'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>()
              .map(AuthorRef.fromJson)
              .toList() ??
          const [],
      narrators:
          (metadata['narrators'] as List<dynamic>?)?.cast<String>() ??
          const [],
      series:
          (metadata['series'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>()
              .map(SeriesRef.fromJson)
              .toList() ??
          const [],
      genres:
          (metadata['genres'] as List<dynamic>?)?.cast<String>() ?? const [],
      description: metadata['description'] as String?,
      publishedYear: metadata['publishedYear'] as String?,
      duration: (media['duration'] as num?)?.toDouble(),
      chapters:
          (media['chapters'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>()
              .map(BookChapter.fromJson)
              .toList() ??
          const [],
      hasEbook: media['ebookFile'] != null,
      progress: progressJson == null
          ? null
          : MediaProgress.fromJson(progressJson),
    );
  }

  final String id;
  final String mediaType;
  final String? coverPath;
  final int updatedAt;
  final String title;
  final String? subtitle;
  final List<AuthorRef> authors;
  final List<String> narrators;
  final List<SeriesRef> series;
  final List<String> genres;
  final String? description;
  final String? publishedYear;
  final double? duration;
  final List<BookChapter> chapters;
  final bool hasEbook;
  final MediaProgress? progress;

  bool get isPodcast => mediaType == 'podcast';
  String get authorNames => authors.map((a) => a.name).join(', ');
}
