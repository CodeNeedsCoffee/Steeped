import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/retry.dart';
import '../../../models/library.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/personalized_shelf.dart';
import '../../../models/search_results.dart';
import '../data/library_repository.dart';
import 'library_items_state.dart';
import 'library_series_state.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.watch(dioProvider));
});

final librariesProvider = FutureProvider<List<Library>>((ref) async {
  return withNetworkRetry(
    () => ref.watch(libraryRepositoryProvider).fetchLibraries(),
  );
});

/// The library currently shown on the home shell / grid. Set once libraries
/// load (defaults to the first one) or when the user switches via the
/// library-picker menu.
final selectedLibraryIdProvider = StateProvider<String?>((ref) => null);

final personalizedShelvesProvider = FutureProvider.autoDispose
    .family<List<PersonalizedShelf>, String>((ref, libraryId) async {
      return withNetworkRetry(
        () => ref
            .watch(libraryRepositoryProvider)
            .fetchPersonalizedShelves(libraryId),
      );
    });

final itemDetailProvider = FutureProvider.autoDispose
    .family<LibraryItemDetail, String>((ref, itemId) async {
      return withNetworkRetry(
        () => ref.watch(libraryRepositoryProvider).fetchItemDetail(itemId),
      );
    });

class LibraryItemsController extends FamilyNotifier<LibraryItemsState, String> {
  late final LibraryRepository _repository;
  late final String _libraryId;

  @override
  LibraryItemsState build(String libraryId) {
    _repository = ref.watch(libraryRepositoryProvider);
    _libraryId = libraryId;
    Future.microtask(loadFirstPage);
    return const LibraryItemsState.initial();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final page = await withNetworkRetry(
        () => _repository.fetchLibraryItems(_libraryId, page: 0),
      );
      state = LibraryItemsState(
        items: page.items,
        total: page.total,
        page: 0,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final nextPage = state.page + 1;
      final page = await withNetworkRetry(
        () => _repository.fetchLibraryItems(_libraryId, page: nextPage),
      );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        page: nextPage,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final libraryItemsProvider =
    NotifierProvider.family<LibraryItemsController, LibraryItemsState, String>(
      LibraryItemsController.new,
    );

/// PLAN.md Phase 4.10: mirrors [LibraryItemsController] exactly, backed by
/// [LibraryRepository.fetchSeries] instead of `fetchLibraryItems`.
class LibrarySeriesController
    extends FamilyNotifier<LibrarySeriesState, String> {
  late final LibraryRepository _repository;
  late final String _libraryId;

  @override
  LibrarySeriesState build(String libraryId) {
    _repository = ref.watch(libraryRepositoryProvider);
    _libraryId = libraryId;
    Future.microtask(loadFirstPage);
    return const LibrarySeriesState.initial();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final page = await withNetworkRetry(
        () => _repository.fetchSeries(_libraryId, page: 0),
      );
      state = LibrarySeriesState(
        series: page.series,
        total: page.total,
        page: 0,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final nextPage = state.page + 1;
      final page = await withNetworkRetry(
        () => _repository.fetchSeries(_libraryId, page: nextPage),
      );
      state = state.copyWith(
        series: [...state.series, ...page.series],
        page: nextPage,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final librarySeriesProvider = NotifierProvider.family<
  LibrarySeriesController,
  LibrarySeriesState,
  String
>(LibrarySeriesController.new);

/// PLAN.md Phase 4.7 (partial: Books + Series). Debounces keystrokes rather
/// than firing one request each, and cancels an in-flight request when a
/// newer query supersedes it -- same dio `CancelToken` idiom already used
/// elsewhere in this app (see `AuthInterceptor`).
class SearchController extends AutoDisposeFamilyNotifier<
  AsyncValue<SearchResults?>,
  String
> {
  late final LibraryRepository _repository;
  late final String _libraryId;
  Timer? _debounce;
  CancelToken? _cancelToken;

  @override
  AsyncValue<SearchResults?> build(String libraryId) {
    _repository = ref.watch(libraryRepositoryProvider);
    _libraryId = libraryId;
    ref.onDispose(() {
      _debounce?.cancel();
      _cancelToken?.cancel();
    });
    return const AsyncData(null);
  }

  void search(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _cancelToken?.cancel();
      state = const AsyncData(null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      _cancelToken?.cancel();
      final cancelToken = CancelToken();
      _cancelToken = cancelToken;
      state = const AsyncLoading<SearchResults?>().copyWithPrevious(state);
      try {
        final results = await _repository.search(
          _libraryId,
          query,
          cancelToken: cancelToken,
        );
        if (cancelToken.isCancelled) return;
        state = AsyncData(results);
      } catch (e, st) {
        if (cancelToken.isCancelled) return;
        state = AsyncError(e, st);
      }
    });
  }
}

final searchControllerProvider = NotifierProvider.autoDispose
    .family<SearchController, AsyncValue<SearchResults?>, String>(
      SearchController.new,
    );
