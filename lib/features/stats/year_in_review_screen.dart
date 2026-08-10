import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/stats_providers.dart';

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
      appBar: AppBar(title: Text('$year in Review')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (stats) {
          final yearSeconds = stats.days.entries
              .where((e) => e.key.startsWith('$year-'))
              .fold(0.0, (sum, e) => sum + e.value);
          final yearDaysListened = stats.days.entries
              .where((e) => e.key.startsWith('$year-') && e.value > 0)
              .length;
          final topItems = stats.itemTimeListening.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          if (yearSeconds == 0) {
            return const Center(
              child: Text('No listening activity yet this year.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Text(
                  _formatDuration(yearSeconds),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              Center(
                child: Text(
                  'listened in $year',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Metric(label: 'Days active', value: '$yearDaysListened'),
                  _Metric(
                    label: 'Longest streak',
                    value: '${stats.currentStreakDays}d',
                  ),
                ],
              ),
              if (topItems.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text('Top Items', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...topItems.take(5).map(
                  (e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Item ${e.key.substring(0, 8)}…'),
                    trailing: Text(_formatDuration(e.value)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(double seconds) {
    final totalHours = seconds / 3600;
    if (totalHours >= 1) return '${totalHours.toStringAsFixed(1)}h';
    return '${(seconds / 60).round()}m';
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
