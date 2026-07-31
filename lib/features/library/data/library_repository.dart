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
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/items',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data ?? const {};
    final results = (data['results'] as List<dynamic>?) ?? const [];
    return LibraryItemsPage(
      items: results.cast<Map<String, dynamic>>().map(LibraryItem.fromJson).toList(),
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? page,
    );
  }

  Future<LibraryItemDetail> fetchItemDetail(String itemId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/items/$itemId',
      queryParameters: {'expanded': 1, 'include': 'progress'},
    );
    return LibraryItemDetail.fromJson(response.data ?? const {});
  }
}
