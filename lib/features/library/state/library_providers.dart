import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../models/library.dart';
import '../../../models/library_item_detail.dart';
import '../../../models/personalized_shelf.dart';
import '../data/library_repository.dart';
import 'library_items_state.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref.watch(dioProvider));
});

final librariesProvider = FutureProvider<List<Library>>((ref) async {
  return ref.watch(libraryRepositoryProvider).fetchLibraries();
});

/// The library currently shown on the home shell / grid. Set once libraries
/// load (defaults to the first one) or when the user switches via the
/// library-picker menu.
final selectedLibraryIdProvider = StateProvider<String?>((ref) => null);

final personalizedShelvesProvider = FutureProvider.autoDispose
    .family<List<PersonalizedShelf>, String>((ref, libraryId) async {
      return ref
          .watch(libraryRepositoryProvider)
          .fetchPersonalizedShelves(libraryId);
    });

final itemDetailProvider = FutureProvider.autoDispose
    .family<LibraryItemDetail, String>((ref, itemId) async {
      return ref.watch(libraryRepositoryProvider).fetchItemDetail(itemId);
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
      final page = await _repository.fetchLibraryItems(_libraryId, page: 0);
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
      final page = await _repository.fetchLibraryItems(
        _libraryId,
        page: nextPage,
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
