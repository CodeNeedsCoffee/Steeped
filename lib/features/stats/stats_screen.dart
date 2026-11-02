import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/listening_stats.dart';
import '../player/mini_player.dart';
import 'state/stats_providers.dart';
import '../../l10n/l10n.dart';
import '../../core/utils/format_duration.dart';

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
        title: Text(context.l10n.stats),
        actions: [
          TextButton(
            onPressed: () => context.push('/stats/year-in-review'),
            child: Text(context.l10n.yearInReview),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(context.l10n.failedToLoad(error))),
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.refresh(listeningStatsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.l10n.last7Days,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _WeekChart(stats: stats),
              const SizedBox(height: 24),
              Text(
                context.l10n.byDayOfWeek,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _WeekdayChart(totals: stats.weekdaySecondsMonFirst),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                children: [
                  _StatTile(
                    label: context.l10n.dailyAverage,
                    value: formatDurationText(
                      context.l10n,
                      stats.dailyAverageSeconds,
                    ),
                  ),
                  _StatTile(
                    label: context.l10n.bestDay,
                    value: formatDurationText(
                      context.l10n,
                      stats.bestDaySeconds,
                    ),
                  ),
                  _StatTile(
                    label: context.l10n.daysListened,
                    value: '${stats.daysListened}',
                  ),
                  _StatTile(
                    label: context.l10n.currentStreak,
                    value: context.l10n.streakDays(stats.currentStreakDays),
                  ),
                  _StatTile(
                    label: context.l10n.thisWeek,
                    value: formatDurationText(
                      context.l10n,
                      stats.lastNDays(7).fold(0.0, (sum, e) => sum + e.value),
                    ),
                  ),
                  _StatTile(
                    label: context.l10n.itemsFinished,
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
                  context.l10n.recentSessions,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...stats.recentSessions
                    .take(10)
                    .map(
                      (s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(s.date),
                        trailing: Text(
                          formatDurationText(context.l10n, s.timeListening),
                        ),
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
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.stats});

  final ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    final days = stats.lastNDays(7);
    final maxValue = days.fold(1.0, (max, e) => e.value > max ? e.value : max);
    final scheme = Theme.of(context).colorScheme;
    final weekday = DateFormat.E(Localizations.localeOf(context).toString());

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
                        entry.value > 0
                            ? context.l10n.durationMinutes(
                                (entry.value / 60).round(),
                              )
                            : '',
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
                        weekday.format(entry.key),
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

/// All-time listening per weekday, Monday first.
class _WeekdayChart extends StatelessWidget {
  const _WeekdayChart({required this.totals});

  final List<double> totals;

  @override
  Widget build(BuildContext context) {
    final maxValue = totals.fold(1.0, (m, v) => v > m ? v : m);
    final scheme = Theme.of(context).colorScheme;
    final format = DateFormat.E(Localizations.localeOf(context).toString());
    // 2024-01-01 was a Monday.
    final names = [
      for (var i = 0; i < 7; i++) format.format(DateTime(2024, 1, 1 + i)),
    ];
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 80 * (totals[i] / maxValue).clamp(0.03, 1.0),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      names[i],
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
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
