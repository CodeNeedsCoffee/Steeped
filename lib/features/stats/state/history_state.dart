import '../../../models/listening_session.dart';

class HistoryState {
  const HistoryState({
    required this.sessions,
    required this.page,
    required this.numPages,
    required this.total,
    required this.isLoading,
    required this.error,
  });

  const HistoryState.initial()
    : sessions = const [],
      page = 0,
      numPages = 1,
      total = 0,
      isLoading = false,
      error = null;

  final List<ListeningSession> sessions;
  final int page;
  final int numPages;
  final int total;
  final bool isLoading;
  final String? error;

  bool get hasMore => page + 1 < numPages;

  HistoryState copyWith({
    List<ListeningSession>? sessions,
    int? page,
    int? numPages,
    int? total,
    bool? isLoading,
    String? error,
  }) {
    return HistoryState(
      sessions: sessions ?? this.sessions,
      page: page ?? this.page,
      numPages: numPages ?? this.numPages,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
