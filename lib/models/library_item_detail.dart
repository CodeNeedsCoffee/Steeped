import 'audio_track.dart';
import 'ebook_file.dart';
import 'media_progress.dart';
import 'podcast_episode.dart';

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
/// (`toOldJSONExpanded`). For a podcast, [episodes] is populated from
/// `media.episodes[]` (PLAN.md Phase 7.1/7.2).
///
/// This class doubles as the player's unit of playback. A single podcast
/// *episode* is represented as a one-track item whose [id] is still the
/// parent podcast's library-item id (so the cover URL and progress endpoint
/// resolve correctly) but with [episodeId] set — see [downloadId] and
/// [PlaybackController.playEpisode].
class LibraryItemDetail {
  const LibraryItemDetail({
    required this.id,
    this.libraryId,
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
    required this.tracks,
    this.episodes = const [],
    this.episodeId,
    this.ebookFile,
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
        libraryId: json['libraryId'] as String?,
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
        tracks: const [],
        episodes:
            (media['episodes'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(
                  (e) => PodcastEpisode.fromJson(
                    e,
                    libraryItemId: json['id'] as String?,
                  ),
                )
                .toList() ??
            const [],
      );
    }

    return LibraryItemDetail(
      id: json['id'] as String,
      libraryId: json['libraryId'] as String?,
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
      tracks:
          (media['tracks'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>()
              .map(AudioTrack.fromJson)
              .toList() ??
          const [],
      ebookFile: media['ebookFile'] == null
          ? null
          : EbookFile.fromJson(media['ebookFile'] as Map<String, dynamic>),
    );
  }

  final String id;
  /// Present on real server responses (`toOldJSONMinified`'s `libraryId`);
  /// null only for the Phase 6.4 offline-rebuilt item, which doesn't need it
  /// since [PLAN.md Phase 6.2]'s series-download only makes sense online.
  final String? libraryId;
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
  final List<AudioTrack> tracks;

  /// Populated only for podcast items (PLAN.md Phase 7.1).
  final List<PodcastEpisode> episodes;

  /// Set only when this item *is* a single podcast episode loaded for
  /// playback (never on a fetched item response). [id] stays the parent
  /// podcast's id in that case.
  final String? episodeId;

  /// Populated for a book item with `media.ebookFile` — covers both text
  /// ebooks and comic archives (PLAN.md Phase 8).
  final EbookFile? ebookFile;

  bool get isPodcast => mediaType == 'podcast';
  bool get isEpisode => episodeId != null;
  String get authorNames => authors.map((a) => a.name).join(', ');

  /// The key downloads and local-playback are stored under. For a book this
  /// is just the library-item id; for a podcast episode it's a composite
  /// `podcastId::episodeId` so multiple episodes of one podcast don't collide
  /// on the [DownloadedItems] primary key — see [DownloadRepository].
  String get downloadId => episodeId == null ? id : '$id::$episodeId';
}
