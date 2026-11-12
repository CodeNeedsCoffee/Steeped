import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../settings/state/settings_providers.dart';
import 'streak.dart';
import 'streak_providers.dart';

/// G5: a quiet reminder on Home when a streak is running but today is still
/// empty. Only from the evening on (an empty morning is normal), dismissible
/// for the rest of the day, and hidden by the Home streak setting.
class StreakBanner extends ConsumerWidget {
  const StreakBanner({super.key, this.now});

  /// For tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final streak = ref.watch(streakProvider).valueOrNull;
    if (settings == null || !settings.showStreak || streak == null) {
      return const SizedBox.shrink();
    }
    final clock = now ?? DateTime.now();
    final today = dayKey(clock);
    if (!streak.atRisk ||
        clock.hour < 17 ||
        ref.watch(streakBannerDismissedProvider) == today) {
      return const SizedBox.shrink();
    }
    final unit = settings.streakWeekly
        ? context.l10n.streakWeeks(streak.current)
        : context.l10n.streakDays(streak.current);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text(context.l10n.streakBanner(unit))),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.dismiss,
                onPressed: () =>
                    ref.read(streakBannerDismissedProvider.notifier).state =
                        today,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the one-time milestone message when the streak reaches 7, 30, 100 or
/// 365 days (4, 12, 26, 52 weeks). Put once in the Home tree.
class StreakMilestoneListener extends ConsumerWidget {
  const StreakMilestoneListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(streakProvider, (_, next) async {
      final streak = next.valueOrNull;
      final settings = ref.read(appSettingsProvider).valueOrNull;
      if (streak == null || settings == null || !settings.showStreak) return;
      final store = ref.read(streakMilestoneStoreProvider);
      final last = await store.load();
      final m = milestoneToCelebrate(
        current: streak.current,
        lastCelebrated: last,
        weekly: settings.streakWeekly,
      );
      if (streak.current < last) await store.save(0);
      if (m == null) return;
      await store.save(m);
      if (!context.mounted) return;
      final unit = settings.streakWeekly
          ? context.l10n.streakWeeks(m)
          : context.l10n.streakDays(m);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.streakMilestone(unit))));
    });
    return child;
  }
}
