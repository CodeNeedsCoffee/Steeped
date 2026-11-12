/// G2-G4: one streak that counts listening (the server's per-day seconds) and
/// reading (seconds recorded on this device). Pure: nothing is stored, so the
/// streak is recomputed from history and cannot drift.
library;

class StreakRules {
  const StreakRules({
    this.thresholdSeconds = 0,
    this.forgiveMissedDay = true,
    this.weekly = false,
  });

  /// A day counts when listening + reading reach this; 0 means any activity.
  final int thresholdSeconds;

  /// Bridge one missed day, at most once per 7 days and never two in a row.
  final bool forgiveMissedDay;

  /// Count weeks (Monday start) with any active day instead of days.
  final bool weekly;
}

class StreakResult {
  const StreakResult({
    required this.current,
    required this.longest,
    required this.todayDone,
    required this.atRisk,
    required this.savedDays,
    this.recent = const [],
  });

  static const none = StreakResult(
    current: 0,
    longest: 0,
    todayDone: false,
    atRisk: false,
    savedDays: 0,
  );

  /// Whether each of the last 7 days (oldest first, today last) met the bar.
  final List<bool> recent;

  /// Days (or weeks in weekly mode) in the current streak.
  final int current;
  final int longest;

  /// Today (this week in weekly mode) already meets the bar.
  final bool todayDone;

  /// A streak is running and today (this week) is still empty.
  final bool atRisk;

  /// Missed days bridged inside the current streak.
  final int savedDays;
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _next(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// [listening] is seconds per `YYYY-MM-DD` in the server's timezone, which can
/// already be tomorrow here, so listening recorded under tomorrow's key makes
/// that day "today". [reading] is seconds per local date.
StreakResult computeStreak({
  required Map<String, double> listening,
  required Map<String, int> reading,
  required StreakRules rules,
  required DateTime now,
}) {
  final localToday = DateTime(now.year, now.month, now.day);
  final today = (listening[dayKey(_next(localToday))] ?? 0) > 0
      ? _next(localToday)
      : localToday;

  double seconds(DateTime d) {
    final k = dayKey(d);
    return (listening[k] ?? 0) + (reading[k] ?? 0);
  }

  bool active(DateTime d) {
    final s = seconds(d);
    return rules.thresholdSeconds <= 0 ? s > 0 : s >= rules.thresholdSeconds;
  }

  final keys = [
    for (final k in [...listening.keys, ...reading.keys])
      if (DateTime.tryParse(k) != null) DateTime.parse(k),
  ]..sort();
  if (keys.isEmpty) return StreakResult.none;
  final first = DateTime(keys.first.year, keys.first.month, keys.first.day);

  final result = rules.weekly
      ? _weekly(first, today, active)
      : _daily(first, today, active, rules.forgiveMissedDay);
  return StreakResult(
    current: result.current,
    longest: result.longest,
    todayDone: result.todayDone,
    atRisk: result.atRisk,
    savedDays: result.savedDays,
    recent: [
      for (var i = 6; i >= 0; i--)
        active(DateTime(today.year, today.month, today.day - i)),
    ],
  );
}

StreakResult _daily(
  DateTime first,
  DateTime today,
  bool Function(DateTime) active,
  bool forgive,
) {
  var run = 0, longest = 0, saved = 0;
  var prevActive = false;
  int? daysSinceBridge; // null: never bridged
  for (var d = first; !d.isAfter(today); d = _next(d)) {
    daysSinceBridge = daysSinceBridge == null ? null : daysSinceBridge + 1;
    if (active(d)) {
      run++;
      prevActive = true;
      if (run > longest) longest = run;
    } else if (d == today) {
      // Today is still open: it neither extends nor breaks the streak.
    } else if (forgive &&
        run > 0 &&
        prevActive &&
        (daysSinceBridge == null || daysSinceBridge >= 7)) {
      saved++;
      daysSinceBridge = 0;
      prevActive = false;
    } else {
      run = 0;
      saved = 0;
      prevActive = false;
    }
  }
  final done = active(today);
  return StreakResult(
    current: run,
    longest: longest,
    todayDone: done,
    atRisk: !done && run > 0,
    savedDays: saved,
  );
}

DateTime _monday(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

StreakResult _weekly(
  DateTime first,
  DateTime today,
  bool Function(DateTime) active,
) {
  var run = 0, longest = 0;
  var done = false;
  final thisWeek = _monday(today);
  for (
    var w = _monday(first);
    !w.isAfter(thisWeek);
    w = DateTime(w.year, w.month, w.day + 7)
  ) {
    var any = false;
    for (var i = 0; i < 7 && !any; i++) {
      final d = DateTime(w.year, w.month, w.day + i);
      if (!d.isAfter(today) && active(d)) any = true;
    }
    if (any) {
      run++;
      if (run > longest) longest = run;
      if (w == thisWeek) done = true;
    } else if (w != thisWeek) {
      run = 0;
    }
  }
  return StreakResult(
    current: run,
    longest: longest,
    todayDone: done,
    atRisk: !done && run > 0,
    savedDays: 0,
  );
}

/// Streak lengths worth a one-time message: days, or weeks in weekly mode.
List<int> streakMilestones({required bool weekly}) =>
    weekly ? const [4, 12, 26, 52] : const [7, 30, 100, 365];

/// The milestone to celebrate now: the largest one the streak has reached that
/// was not already celebrated, or null. A streak that fell below the last
/// celebrated milestone has started over, so [lastCelebrated] no longer holds.
int? milestoneToCelebrate({
  required int current,
  required int lastCelebrated,
  required bool weekly,
}) {
  final base = current < lastCelebrated ? 0 : lastCelebrated;
  int? best;
  for (final m in streakMilestones(weekly: weekly)) {
    if (current >= m && m > base) best = m;
  }
  return best;
}
