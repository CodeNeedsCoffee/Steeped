import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/retry.dart';
import '../../../core/storage/app_database.dart';
import '../../../models/library.dart';
import '../../../models/library_browse.dart';
import '../../../models/library_query.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/personalized_shelf.dart';
import '../../../models/search_results.dart';
import '../../downloads/state/download_controller.dart';
import '../data/library_cache_repository.dart';
import '../data/library_query_store.dart';
import '../data/recent_searches_store.dart';
import '../data/library_repository.dart';
import 'library_items_state.dart';
import 'library_series_state.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.watch(dioProvider));
});

final libraryCacheRepositoryProvider = Provider<LibraryCacheRepository>((ref) {
  return LibraryCacheRepository(ref.watch(appDatabaseProvider));
});

/// The last successfully-fetched library list. Only consulted when
/// [librariesProvider] fails — see [HomeShellScreen]'s offline fallback.
final cachedLibrariesProvider = FutureProvider<List<Library>>((ref) {
  return ref.watch(libraryCacheRepositoryProvider).load();
});

final librariesProvider = FutureProvider<List<Library>>((ref) async {
  final libraries = await withNetworkRetry(
    () => ref.watch(libraryRepositoryProvider).fetchLibraries(),
  );
  // Not awaited: persisting the cache is a side effect for a *future* cold
  // start, so making this fetch's consumers wait on a disk write would only
  // delay the UI for no benefit here.
  unawaited(ref.read(libraryCacheRepositoryProvider).save(libraries));
  return libraries;
});

/// Stand-in for the server's "Continue Listening" shelf when the app starts
/// with no connectivity: everything playable from local storage alone.
///
/// A null [DownloadedItem.libraryId] (a row written before that column
/// existed) shows under every library — hiding a genuinely downloaded book
/// because it lacks a tag would be worse than showing it in the wrong place.
/// There's no local "last played" timestamp, so ordering approximates the
/// server shelf as closely as local data allows: started items first, then
/// unstarted, each newest-download-first.
List<DownloadedItem> offlineContinueListeningItems(
  List<DownloadedItem> downloads,
  String libraryId,
) {
  final eligible = downloads
      .where(
        (d) =>
            d.status == 'complete' &&
            !d.progressIsFinished &&
            (d.libraryId == null || d.libraryId == libraryId),
      )
      .toList();
  eligible.sort((a, b) {
    final aStarted = (a.progressCurrentTime ?? 0) > 0;
    final bStarted = (b.progressCurrentTime ?? 0) > 0;
    if (aStarted != bStarted) return aStarted ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  });
  return eligible;
}

final offlineContinueListeningProvider =
    Provider.family<List<DownloadedItem>, String>((ref, libraryId) {
      return offlineContinueListeningItems(
        ref.watch(downloadsListProvider).valueOrNull ?? const [],
        libraryId,
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

final libraryQueryStoreProvider = Provider<LibraryQueryStore>(
  (ref) => LibraryQueryStore(ref.watch(appDatabaseProvider)),
);

/// LIBRARY_PLAN.md L4: the Books grid's sort / filter / view mode for one
/// library, persisted per library. Starts at the default and swaps in the
/// saved value as soon as it's read (a no-op if they're equal).
class LibraryQueryController extends FamilyNotifier<LibraryQuery, String> {
  late String _libraryId;

  @override
  LibraryQuery build(String libraryId) {
    _libraryId = libraryId;
    var disposed = false;
    ref.onDispose(() => disposed = true);
    Future.microtask(() async {
      final saved = await ref.read(libraryQueryStoreProvider).load(libraryId);
      if (!disposed) state = saved;
    });
    return const LibraryQuery();
  }

  void update(LibraryQuery query) {
    state = query;
    unawaited(ref.read(libraryQueryStoreProvider).save(_libraryId, query));
  }
}

final libraryQueryProvider =
    NotifierProvider.family<LibraryQueryController, LibraryQuery, String>(
      LibraryQueryController.new,
    );

final libraryFilterDataProvider = FutureProvider.autoDispose
    .family<LibraryFilterData, String>((ref, libraryId) {
      return withNetworkRetry(
        () => ref.watch(libraryRepositoryProvider).fetchFilterData(libraryId),
      );
    });

final authorsProvider = FutureProvider.autoDispose.family<List<Author>, String>(
  (ref, libraryId) => withNetworkRetry(
    () => ref.watch(libraryRepositoryProvider).fetchAuthors(libraryId),
  ),
);

final authorDetailProvider = FutureProvider.autoDispose.family<Author, String>(
  (ref, authorId) => withNetworkRetry(
    () => ref.watch(libraryRepositoryProvider).fetchAuthor(authorId),
  ),
);

final collectionsProvider = FutureProvider.autoDispose
    .family<List<LibraryCollection>, String>(
      (ref, libraryId) => withNetworkRetry(
        () => ref.watch(libraryRepositoryProvider).fetchCollections(libraryId),
      ),
    );

final collectionDetailProvider = FutureProvider.autoDispose
    .family<LibraryCollection, String>(
      (ref, id) => withNetworkRetry(
        () => ref.watch(libraryRepositoryProvider).fetchCollection(id),
      ),
    );

final playlistsProvider = FutureProvider.autoDispose
    .family<List<Playlist>, String>(
      (ref, libraryId) => withNetworkRetry(
        () => ref.watch(libraryRepositoryProvider).fetchPlaylists(libraryId),
      ),
    );

final playlistDetailProvider = FutureProvider.autoDispose
    .family<Playlist, String>(
      (ref, id) => withNetworkRetry(
        () => ref.watch(libraryRepositoryProvider).fetchPlaylist(id),
      ),
    );

class LibraryItemsController extends FamilyNotifier<LibraryItemsState, String> {
  late LibraryRepository _repository;
  late String _libraryId;
  late LibraryQuery _query;

  @override
  LibraryItemsState build(String libraryId) {
    _repository = ref.watch(libraryRepositoryProvider);
    _libraryId = libraryId;
    _query = ref.watch(libraryQueryProvider(libraryId));
    Future.microtask(loadFirstPage);
    return const LibraryItemsState.initial();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final page = await withNetworkRetry(
        () => _repository.fetchLibraryItems(
          _libraryId,
          page: 0,
          filter: _query.filterParam,
          sort: _query.sort.param,
          desc: _query.desc,
        ),
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
        () => _repository.fetchLibraryItems(
          _libraryId,
          page: nextPage,
          filter: _query.filterParam,
          sort: _query.sort.param,
          desc: _query.desc,
        ),
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

final recentSearchesStoreProvider = Provider<RecentSearchesStore>(
  (ref) => RecentSearchesStore(ref.watch(appDatabaseProvider)),
);

class RecentSearchesController extends Notifier<List<String>> {
  @override
  List<String> build() {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    Future.microtask(() async {
      final saved = await ref.read(recentSearchesStoreProvider).load();
      if (!disposed) state = saved;
    });
    return const [];
  }

  Future<void> add(String term) async {
    state = await ref.read(recentSearchesStoreProvider).add(term);
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(recentSearchesStoreProvider).clear();
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<String>>(
      RecentSearchesController.new,
    );
