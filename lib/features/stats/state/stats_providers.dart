import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../models/listening_stats.dart';
import '../data/stats_repository.dart';
import 'history_state.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(dioProvider));
});

final listeningStatsProvider = FutureProvider.autoDispose<ListeningStats>((
  ref,
) {
  return ref.read(statsRepositoryProvider).fetchListeningStats();
});

final finishedItemsCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.read(statsRepositoryProvider).fetchFinishedItemsCount();
});

class HistoryController extends Notifier<HistoryState> {
  late final StatsRepository _repository;

  @override
  HistoryState build() {
    _repository = ref.watch(statsRepositoryProvider);
    Future.microtask(loadFirstPage);
    return const HistoryState.initial();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final page = await _repository.fetchListeningSessions(page: 0);
      state = HistoryState(
        sessions: page.sessions,
        page: 0,
        numPages: page.numPages,
        total: page.total,
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
      final page = await _repository.fetchListeningSessions(page: nextPage);
      state = state.copyWith(
        sessions: [...state.sessions, ...page.sessions],
        page: nextPage,
        numPages: page.numPages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryState>(HistoryController.new);
