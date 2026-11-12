import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_database.dart';
import '../auth/state/session_controller.dart' show activeProfileIdProvider;
import '../settings/state/settings_providers.dart';
import '../stats/state/stats_providers.dart';
import 'reading_days_store.dart';
import 'streak.dart';

final readingDaysStoreProvider = Provider<ReadingDaysStore>(
  (ref) => ReadingDaysStore(
    ref.watch(appDatabaseProvider),
    profileId: ref.watch(activeProfileIdProvider) ?? '',
  ),
);

final streakMilestoneStoreProvider = Provider<StreakMilestoneStore>(
  (ref) => StreakMilestoneStore(
    ref.watch(appDatabaseProvider),
    profileId: ref.watch(activeProfileIdProvider) ?? '',
  ),
);

/// The day (`YYYY-MM-DD`) the at-risk banner was dismissed, for this run.
final streakBannerDismissedProvider = StateProvider<String?>((ref) => null);

final readingDaysProvider = FutureProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(readingDaysStoreProvider).load(),
);

/// The merged listening + reading streak under the user's rules. Falls back
/// to reading only when the server's stats cannot be fetched (offline).
final streakProvider = FutureProvider.autoDispose<StreakResult>((ref) async {
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  final reading = await ref.watch(readingDaysProvider.future);
  Map<String, double> listening = const {};
  try {
    listening = (await ref.watch(listeningStatsProvider.future)).days;
  } catch (_) {}
  return computeStreak(
    listening: listening,
    reading: reading,
    rules: StreakRules(
      thresholdSeconds: (settings?.streakGoalMinutes ?? 0) * 60,
      forgiveMissedDay: settings?.streakForgive ?? true,
      weekly: settings?.streakWeekly ?? false,
    ),
    now: DateTime.now(),
  );
});

/// A reader calls [touch] on every page turn, scroll or tap; the tracker
/// banks the active seconds into today's total about every 30 s and on
/// [close]. Holds the app's container, which outlives the reader, so the final
/// write after the screen is gone still lands.
class ReadingTracker {
  ReadingTracker(this._container) {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _flush());
  }

  final ProviderContainer _container;
  final _clock = ReadingClock();
  late final Timer _timer;

  void touch() => _clock.touch(DateTime.now());

  Future<void> _flush() async {
    final seconds = _clock.takePending();
    if (seconds <= 0) return;
    await _container
        .read(readingDaysStoreProvider)
        .add(DateTime.now(), seconds);
    _container.invalidate(readingDaysProvider);
  }

  Future<void> close() async {
    _timer.cancel();
    _clock.pause();
    await _flush();
  }
}
