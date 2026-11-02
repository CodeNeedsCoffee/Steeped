import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../player/mini_player.dart';
import 'state/stats_providers.dart';
import '../../l10n/l10n.dart';
import '../../core/utils/format_duration.dart';

/// PLAN.md Phase 9.7: `GET /api/me/listening-sessions`, confirmed live
/// against evan's real server (2026-07-31) — paginated, 1228 real sessions
/// on his account.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(historyControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.historyWithCount(state.total))),
      body: state.sessions.isEmpty && state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.sessions.isEmpty
          ? Center(child: Text(context.l10n.failedToLoad(state.error ?? '')))
          : state.sessions.isEmpty
          ? Center(child: Text(context.l10n.noListeningHistoryYet))
          : RefreshIndicator(
              onRefresh: ref
                  .read(historyControllerProvider.notifier)
                  .loadFirstPage,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                itemCount: state.sessions.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.sessions.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final session = state.sessions[index];
                  return ListTile(
                    title: Text(
                      session.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (session.displayAuthor != null)
                          session.displayAuthor!,
                        session.date,
                      ].join(' · '),
                    ),
                    trailing: Text(
                      formatDurationText(context.l10n, session.timeListening),
                    ),
                    onTap: () => context.push('/item/${session.libraryItemId}'),
                  );
                },
              ),
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
