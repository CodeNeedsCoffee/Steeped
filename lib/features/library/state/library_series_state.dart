import '../../../models/library_series.dart';

/// Mirrors [LibraryItemsState] exactly -- same paginated-grid shape, one
/// series per tile instead of one book per tile.
class LibrarySeriesState {
  const LibrarySeriesState({
    required this.series,
    required this.total,
    required this.page,
    required this.isLoading,
    required this.error,
  });

  const LibrarySeriesState.initial()
    : series = const [],
      total = 0,
      page = -1,
      isLoading = true,
      error = null;

  final List<LibrarySeries> series;
  final int total;
  final int page;
  final bool isLoading;
  final String? error;

  bool get hasMore => series.length < total;

  LibrarySeriesState copyWith({
    List<LibrarySeries>? series,
    int? total,
    int? page,
    bool? isLoading,
    String? error,
  }) {
    return LibrarySeriesState(
      series: series ?? this.series,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
