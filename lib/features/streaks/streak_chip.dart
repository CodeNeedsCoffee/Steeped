import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../settings/state/settings_providers.dart';
import 'streak_providers.dart';

/// G5: a flame and the current streak in the Home bar. Quiet when there is no
/// streak yet, outlined while today is still empty, and hidden by the setting.
class StreakChip extends ConsumerWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    if (settings == null || !settings.showStreak) {
      return const SizedBox.shrink();
    }
    final streak = ref.watch(streakProvider).valueOrNull;
    if (streak == null || streak.current == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final unit = settings.streakWeekly
        ? context.l10n.streakWeeks(streak.current)
        : context.l10n.streakDays(streak.current);
    return Tooltip(
      message: [
        unit,
        if (streak.savedDays > 0)
          context.l10n.streakSavedDays(streak.savedDays),
        if (streak.atRisk) context.l10n.streakAtRisk,
      ].join(' · '),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/stats'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 20,
                color: streak.todayDone ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 2),
              Text(
                '${streak.current}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
