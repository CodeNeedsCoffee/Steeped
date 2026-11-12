import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../settings/state/settings_providers.dart';
import 'streak.dart';
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
    return StreakChipView(
      streak: ref.watch(streakProvider).valueOrNull ?? StreakResult.none,
      weekly: settings.streakWeekly,
    );
  }
}

/// The chip itself. With no streak it still shows, dimmed, with a 0, so the
/// feature is discoverable before the first active day.
class StreakChipView extends StatelessWidget {
  const StreakChipView({required this.streak, required this.weekly, super.key});

  final StreakResult streak;
  final bool weekly;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = weekly
        ? context.l10n.streakWeeks(streak.current)
        : context.l10n.streakDays(streak.current);
    final dimmed = streak.current == 0;
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
        child: Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 20,
                  color: streak.todayDone && !dimmed
                      ? scheme.primary
                      : scheme.outline,
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
      ),
    );
  }
}
