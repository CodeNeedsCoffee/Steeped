import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/listening_stats.dart';
import '../player/mini_player.dart';
import 'state/stats_providers.dart';

/// PLAN.md Phase 9.4: minutes-listening 7-day chart, best day, daily
/// average, days listened, streak, items finished, week listening. All
/// computed from `GET /api/me/listening-stats`, confirmed live against
/// evan's real server (2026-07-31).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(listeningStatsProvider);
    final finishedAsync = ref.watch(finishedItemsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          TextButton(
            onPressed: () => context.push('/stats/year-in-review'),
            child: const Text('Year in Review'),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.refresh(listeningStatsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Last 7 Days', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _WeekChart(stats: stats),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                children: [
                  _StatTile(
                    label: 'Daily average',
                    value: _formatDuration(stats.dailyAverageSeconds),
                  ),
                  _StatTile(
                    label: 'Best day',
                    value: _formatDuration(stats.bestDaySeconds),
                  ),
                  _StatTile(
                    label: 'Days listened',
                    value: '${stats.daysListened}',
                  ),
                  _StatTile(
                    label: 'Current streak',
                    value: '${stats.currentStreakDays} day${stats.currentStreakDays == 1 ? '' : 's'}',
                  ),
                  _StatTile(
                    label: 'This week',
                    value: _formatDuration(
                      stats.lastNDays(7).fold(0.0, (sum, e) => sum + e.value),
                    ),
                  ),
                  _StatTile(
                    label: 'Items finished',
                    value: finishedAsync.when(
                      data: (count) => '$count',
                      loading: () => '…',
                      error: (_, _) => '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (stats.recentSessions.isNotEmpty) ...[
                Text(
                  'Recent Sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...stats.recentSessions.take(10).map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(s.date),
                    trailing: Text(_formatDuration(s.timeListening)),
                    onTap: () => context.push('/item/${s.libraryItemId}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  String _formatDuration(double seconds) {
    final totalMinutes = (seconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.stats});

  final ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    final days = stats.lastNDays(7);
    final maxValue = days.fold(1.0, (max, e) => e.value > max ? e.value : max);
    final scheme = Theme.of(context).colorScheme;
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days
            .map(
              (entry) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        entry.value > 0 ? '${(entry.value / 60).round()}m' : '',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 90 * (entry.value / maxValue).clamp(0.03, 1.0),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weekdayLabels[entry.key.weekday - 1],
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
