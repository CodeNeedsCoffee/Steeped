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

/// One item's listening total for a year-in-review ranking.
class YearItemTotal {
  const YearItemTotal({
    required this.libraryItemId,
    required this.title,
    required this.seconds,
  });

  final String libraryItemId;
  final String title;
  final double seconds;
}

/// Top items for [year], summed from the listening sessions dated in that
/// year. (`/api/me/listening-stats` only has all-time per-item totals, which
/// would put last year's favourites in this year's review.)
final yearTopItemsProvider = FutureProvider.autoDispose
    .family<List<YearItemTotal>, int>((ref, year) async {
      final repository = ref.read(statsRepositoryProvider);
      final prefix = '$year-';
      final totals = <String, double>{};
      final titles = <String, String>{};
      // Newest first; stop once a whole page predates the year.
      for (var page = 0; page < 50; page++) {
        final result = await repository.fetchListeningSessions(
          page: page,
          itemsPerPage: 100,
        );
        var anyInYearOrNewer = false;
        for (final session in result.sessions) {
          if (session.date.compareTo(prefix) >= 0) anyInYearOrNewer = true;
          if (!session.date.startsWith(prefix)) continue;
          totals.update(
            session.libraryItemId,
            (v) => v + session.timeListening,
            ifAbsent: () => session.timeListening,
          );
          titles[session.libraryItemId] = session.displayTitle;
        }
        if (!anyInYearOrNewer || page + 1 >= result.numPages) break;
      }
      return [
        for (final e in totals.entries)
          YearItemTotal(
            libraryItemId: e.key,
            title: titles[e.key] ?? '',
            seconds: e.value,
          ),
      ]..sort((a, b) => b.seconds.compareTo(a.seconds));
    });
