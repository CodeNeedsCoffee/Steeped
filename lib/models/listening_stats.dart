import 'listening_session.dart';

/// `GET /api/me/listening-stats` — confirmed live against evan's real
/// server (2026-07-31). `days` keys are `YYYY-MM-DD`, values are seconds;
/// `dayOfWeek` keys are weekday names (`Monday`..`Sunday`), values are
/// **all-time cumulative** seconds for that weekday (not a single best
/// day) — used for the "which weekday do you listen most" view, distinct
/// from the single best individual day (computed client-side from [days]).
class ListeningStats {
  const ListeningStats({
    required this.totalTimeSeconds,
    required this.days,
    required this.weekdayTotals,
    required this.todaySeconds,
    required this.recentSessions,
    required this.itemTimeListening,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  factory ListeningStats.fromJson(Map<String, dynamic> json) {
    final daysJson = (json['days'] as Map<String, dynamic>?) ?? const {};
    final weekdayJson =
        (json['dayOfWeek'] as Map<String, dynamic>?) ?? const {};
    final recentJson = (json['recentSessions'] as List<dynamic>?) ?? const [];
    final itemsJson = (json['items'] as Map<String, dynamic>?) ?? const {};

    return ListeningStats(
      totalTimeSeconds: (json['totalTime'] as num?)?.toDouble() ?? 0,
      days: daysJson.map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0)),
      weekdayTotals: weekdayJson.map(
        (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0),
      ),
      todaySeconds: (json['today'] as num?)?.toDouble() ?? 0,
      recentSessions: recentJson
          .cast<Map<String, dynamic>>()
          .map(ListeningSession.fromJson)
          .toList(),
      itemTimeListening: itemsJson.map(
        (k, v) => MapEntry(
          k,
          ((v as Map<String, dynamic>)['timeListening'] as num?)?.toDouble() ??
              0,
        ),
      ),
    );
  }

  final double totalTimeSeconds;
  final Map<String, double> days;
  final Map<String, double> weekdayTotals;
  final double todaySeconds;
  final List<ListeningSession> recentSessions;
  final Map<String, double> itemTimeListening;
  final DateTime Function() _now;

  /// The last [count] calendar days ending today, oldest first — zero-filled
  /// for days with no listening, since [days] only has entries for days
  /// with activity.
  List<MapEntry<DateTime, double>> lastNDays(int count) {
    final now = _anchorDay();
    return List.generate(count, (i) {
      final date = DateTime(now.year, now.month, now.day - (count - 1 - i));
      final key =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      return MapEntry(date, days[key] ?? 0);
    });
  }

  int get daysListened => days.values.where((v) => v > 0).length;

  double get bestDaySeconds =>
      days.values.fold(0.0, (max, v) => v > max ? v : max);

  double get dailyAverageSeconds =>
      daysListened == 0 ? 0 : totalTimeSeconds / daysListened;

  /// Consecutive days with listening activity, counting back from today
  /// (or yesterday, if nothing logged yet today).
  int get currentStreakDays {
    var streak = 0;
    var date = _anchorDay();
    // Allow "today" to be empty without breaking the streak (haven't
    // listened yet today, but did yesterday).
    if ((days[_key(date)] ?? 0) <= 0) {
      date = date.subtract(const Duration(days: 1));
    }
    while ((days[_key(date)] ?? 0) > 0) {
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Longest run of consecutive listening days within [year].
  int longestStreakInYear(int year) {
    var best = 0;
    var run = 0;
    var date = DateTime(year, 1, 1);
    while (date.year == year) {
      if ((days[_key(date)] ?? 0) > 0) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
      date = DateTime(date.year, date.month, date.day + 1);
    }
    return best;
  }

  /// Seconds listened per weekday (index 0 = Monday ... 6 = Sunday), from
  /// the server's all-time `dayOfWeek` totals.
  List<double> get weekdaySecondsMonFirst {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return [for (final n in names) weekdayTotals[n] ?? 0];
  }

  /// "Today" for [days]. The keys are dates in the *server's* timezone, which
  /// can already be tomorrow here (a UTC server in the evening, west of
  /// UTC). If listening is recorded under tomorrow's key, that is today.
  DateTime _anchorDay() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return (days[_key(tomorrow)] ?? 0) > 0 ? tomorrow : today;
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
