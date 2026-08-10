import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../models/library.dart';
import '../../../models/library_item.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/personalized_shelf.dart';

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
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/items',
      queryParameters: {'page': page, 'limit': limit, 'filter': ?filter},
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
}
