import '../../../models/library_item.dart';

class LibraryItemsState {
  const LibraryItemsState({
    required this.items,
    required this.total,
    required this.page,
    required this.isLoading,
    required this.error,
  });

  const LibraryItemsState.initial()
    : items = const [],
      total = 0,
      page = -1,
      isLoading = true,
      error = null;

  final List<LibraryItem> items;
  final int total;
  final int page;
  final bool isLoading;
  final String? error;

  bool get hasMore => items.length < total;

  LibraryItemsState copyWith({
    List<LibraryItem>? items,
    int? total,
    int? page,
    bool? isLoading,
    String? error,
  }) {
    return LibraryItemsState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
