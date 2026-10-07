import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../models/library.dart';
import '../../../models/library_item.dart';
import '../../../models/library_browse.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/library_query.dart';
import '../../../models/library_series.dart';
import '../../../models/personalized_shelf.dart';
import '../../../models/search_results.dart';

class LibraryItemsPage {
  const LibraryItemsPage({
    required this.items,
    required this.total,
    required this.page,
  });

  final List<LibraryItem> items;
  final int total;
  final int page;
}

class LibrarySeriesPage {
  const LibrarySeriesPage({
    required this.series,
    required this.total,
    required this.page,
  });

  final List<LibrarySeries> series;
  final int total;
  final int page;
}

/// Talks to the authenticated library-browsing endpoints. Uses the shared,
/// interceptor-attached `dioProvider` Dio (unlike [AuthRepository], these
/// all require an established session).
class LibraryRepository {
  const LibraryRepository(this._dio);

  final Dio _dio;

  Future<List<Library>> fetchLibraries() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/libraries');
    final list = (response.data?['libraries'] as List<dynamic>?) ?? const [];
    return list.cast<Map<String, dynamic>>().map(Library.fromJson).toList();
  }

  Future<List<PersonalizedShelf>> fetchPersonalizedShelves(
    String libraryId, {
    int limit = 10,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/libraries/$libraryId/personalized',
      queryParameters: {'limit': limit},
    );
    final list = response.data ?? const [];
    return list
        .cast<Map<String, dynamic>>()
        .map(PersonalizedShelf.fromJson)
        .toList();
  }

  Future<LibraryItemsPage> fetchLibraryItems(
    String libraryId, {
    required int page,
    int limit = 40,
    String? filter,
    String? sort,
    bool desc = false,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/items',
      queryParameters: {
        'page': page,
        'limit': limit,
        'filter': ?filter,
        'sort': ?sort,
        if (sort != null && desc) 'desc': 1,
      },
    );
    final data = response.data ?? const {};
    final results = (data['results'] as List<dynamic>?) ?? const [];
    return LibraryItemsPage(
      items: results.cast<Map<String, dynamic>>().map(LibraryItem.fromJson).toList(),
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? page,
    );
  }

  /// PLAN.md Phase 6.2: every item in [seriesId] within [libraryId], for
  /// "download series". The `filter` query param's `<group>.<base64(value)>`
  /// shape is confirmed against `~/Code/audiobookshelf/server/utils/queries/
  /// libraryFilters.js`'s `decode` — the same `/items` endpoint 4.4 already
  /// uses, no separate series-browse endpoint (4.5) required. Loops pages
  /// since a series filter isn't guaranteed to fit in one page.
  Future<List<LibraryItem>> fetchItemsInSeries(
    String libraryId,
    String seriesId,
  ) async {
    final filter = 'series.${base64.encode(utf8.encode(seriesId))}';
    final items = <LibraryItem>[];
    var page = 0;
    while (true) {
      final result = await fetchLibraryItems(
        libraryId,
        page: page,
        limit: 100,
        filter: filter,
      );
      items.addAll(result.items);
      if (items.length >= result.total || result.items.isEmpty) break;
      page++;
    }
    return items;
  }

  Future<LibraryItemDetail> fetchItemDetail(String itemId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/items/$itemId',
      queryParameters: {'expanded': 1, 'include': 'progress'},
    );
    return LibraryItemDetail.fromJson(response.data ?? const {});
  }

  /// PLAN.md Phase 4.10: dedicated series-browse endpoint, confirmed live
  /// against a real Audiobookshelf server (`GET /api/libraries/:id/series`)
  /// — same paginated shape as [fetchLibraryItems], each series entry
  /// already embedding full book objects (its cover source), so no
  /// second request per series is needed.
  Future<LibrarySeriesPage> fetchSeries(
    String libraryId, {
    required int page,
    int limit = 40,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/series',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data ?? const {};
    final results = (data['results'] as List<dynamic>?) ?? const [];
    return LibrarySeriesPage(
      series: results
          .cast<Map<String, dynamic>>()
          .map(LibrarySeries.fromJson)
          .toList(),
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? page,
    );
  }

  /// PLAN.md Phase 4.7 (partial: Books + Series only). Confirmed live that
  /// the real endpoint groups results by category — `book`, `series`,
  /// `authors`, `narrators`, `tags`, `genres` — each a separate array;
  /// [SearchResults.fromJson] only reads the two used by this pass.
  Future<SearchResults> search(
    String libraryId,
    String query, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/search',
      queryParameters: {'q': query},
      cancelToken: cancelToken,
    );
    return SearchResults.fromJson(response.data ?? const {});
  }

  // ---- LIBRARY_PLAN.md L1/L4: filter data, authors, collections, playlists

  Future<LibraryFilterData> fetchFilterData(String libraryId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/filterdata',
    );
    return LibraryFilterData.fromJson(r.data ?? const {});
  }

  Future<List<Author>> fetchAuthors(String libraryId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/authors',
    );
    final list = (r.data?['authors'] as List<dynamic>?) ?? const [];
    final authors = list
        .whereType<Map<String, dynamic>>()
        .map(Author.fromJson)
        .toList();
    authors.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return authors;
  }

  Future<Author> fetchAuthor(String authorId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/authors/$authorId',
      queryParameters: {'include': 'items,series'},
    );
    return Author.fromJson(r.data ?? const {});
  }

  Future<List<LibraryCollection>> fetchCollections(String libraryId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/collections',
    );
    final list = (r.data?['results'] as List<dynamic>?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(LibraryCollection.fromJson)
        .toList();
  }

  Future<LibraryCollection> fetchCollection(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/api/collections/$id');
    return LibraryCollection.fromJson(r.data ?? const {});
  }

  Future<LibraryCollection> createCollection({
    required String libraryId,
    required String name,
    List<String> bookIds = const [],
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/collections',
      data: {'libraryId': libraryId, 'name': name, 'books': bookIds},
    );
    return LibraryCollection.fromJson(r.data ?? const {});
  }

  /// Rename and/or replace the full book list (order = list order).
  Future<void> updateCollection(
    String id, {
    String? name,
    List<String>? bookIds,
  }) => _dio.patch<void>(
    '/api/collections/$id',
    data: {'name': ?name, 'books': ?bookIds},
  );

  Future<void> deleteCollection(String id) =>
      _dio.delete<void>('/api/collections/$id');

  Future<void> addBookToCollection(String id, String bookId) =>
      _dio.post<void>('/api/collections/$id/book', data: {'id': bookId});

  Future<void> removeBookFromCollection(String id, String bookId) =>
      _dio.delete<void>('/api/collections/$id/book/$bookId');

  Future<List<Playlist>> fetchPlaylists(String libraryId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/playlists',
    );
    final list = (r.data?['results'] as List<dynamic>?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Playlist.fromJson)
        .toList();
  }

  Future<Playlist> fetchPlaylist(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/api/playlists/$id');
    return Playlist.fromJson(r.data ?? const {});
  }

  Future<Playlist> createPlaylist({
    required String libraryId,
    required String name,
    List<({String libraryItemId, String? episodeId})> items = const [],
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/playlists',
      data: {
        'libraryId': libraryId,
        'name': name,
        'items': [
          for (final i in items)
            {'libraryItemId': i.libraryItemId, 'episodeId': ?i.episodeId},
        ],
      },
    );
    return Playlist.fromJson(r.data ?? const {});
  }

  Future<void> renamePlaylist(String id, String name) =>
      _dio.patch<void>('/api/playlists/$id', data: {'name': name});

  /// Confirmed against `PlaylistController.update`: a non-empty `items`
  /// array rewrites the playlist order.
  Future<void> reorderPlaylist(String id, List<PlaylistItem> items) =>
      _dio.patch<void>(
        '/api/playlists/$id',
        data: {
          'items': [
            for (final i in items)
              {'libraryItemId': i.libraryItemId, 'episodeId': ?i.episodeId},
          ],
        },
      );

  Future<void> deletePlaylist(String id) =>
      _dio.delete<void>('/api/playlists/$id');

  Future<void> addToPlaylist(
    String id,
    String libraryItemId, {
    String? episodeId,
  }) => _dio.post<void>(
    '/api/playlists/$id/item',
    data: {'libraryItemId': libraryItemId, 'episodeId': ?episodeId},
  );

  Future<void> removeFromPlaylist(
    String id,
    String libraryItemId, {
    String? episodeId,
  }) => _dio.delete<void>(
    '/api/playlists/$id/item/$libraryItemId${episodeId == null ? '' : '/$episodeId'}',
  );
}
