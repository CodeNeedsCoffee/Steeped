import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/stats_providers.dart';
import '../../l10n/l10n.dart';

/// PLAN.md Phase 9.5: annual recap. No dedicated server endpoint was found
/// for this (only `/api/me/listening-stats`, confirmed live) — built by
/// aggregating that same data client-side, filtered to the current year,
/// rather than guessing at an unconfirmed `/api/me/annual-stats`-style
/// endpoint. Top items are ranked by minutes listened this year.
class YearInReviewScreen extends ConsumerWidget {
  const YearInReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(listeningStatsProvider);
    final year = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.inReview(year))),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(context.l10n.failedToLoad(error))),
        data: (stats) {
          final yearSeconds = stats.days.entries
              .where((e) => e.key.startsWith('$year-'))
              .fold(0.0, (sum, e) => sum + e.value);
          final yearDaysListened = stats.days.entries
              .where((e) => e.key.startsWith('$year-') && e.value > 0)
              .length;
          final topItems =
              ref.watch(yearTopItemsProvider(year)).valueOrNull ?? const [];

          if (yearSeconds == 0) {
            return Center(child: Text(context.l10n.noListeningActivityYetThis));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Text(
                  _formatDuration(context, yearSeconds),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              Center(
                child: Text(
                  context.l10n.listenedIn(year),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Metric(
                    label: context.l10n.daysActive,
                    value: '$yearDaysListened',
                  ),
                  _Metric(
                    label: context.l10n.longestStreak,
                    value: context.l10n.streakDaysShort(
                      stats.longestStreakInYear(year),
                    ),
                  ),
                ],
              ),
              if (topItems.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  context.l10n.topItems,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...topItems
                    .take(5)
                    .map(
                      (e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(_formatDuration(context, e.seconds)),
                        onTap: () => context.push('/item/${e.libraryItemId}'),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(BuildContext context, double seconds) {
    final totalHours = seconds / 3600;
    if (totalHours >= 1) {
      return context.l10n.durationHoursDecimal(totalHours.toStringAsFixed(1));
    }
    return context.l10n.durationMinutes((seconds / 60).round());
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
