import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/models/listening_stats.dart';

ListeningStats stats(Map<String, double> days, DateTime now) => ListeningStats(
  totalTimeSeconds: 0,
  days: days,
  weekdayTotals: const {},
  todaySeconds: 0,
  recentSessions: const [],
  itemTimeListening: const {},
  now: () => now,
);

void main() {
  final now = DateTime(2026, 10, 30, 21);

  test('streak counts back from today', () {
    final s = stats({
      '2026-10-30': 60,
      '2026-10-29': 60,
      '2026-10-28': 60,
      '2026-10-26': 60,
    }, now);
    expect(s.currentStreakDays, 3);
  });

  test('an empty today does not break yesterday\'s streak', () {
    final s = stats({'2026-10-29': 60, '2026-10-28': 60}, now);
    expect(s.currentStreakDays, 2);
  });

  test('server date already tomorrow counts as today', () {
    // A UTC server logs this evening's listening under tomorrow's date.
    final s = stats({'2026-10-31': 60, '2026-10-30': 60, '2026-10-29': 60}, now);
    expect(s.currentStreakDays, 3);
    expect(s.lastNDays(7).last.value, 60);
    expect(s.lastNDays(7).last.key, DateTime(2026, 10, 31));
  });

  test('streak is zero after a gap', () {
    final s = stats({'2026-10-27': 60}, now);
    expect(s.currentStreakDays, 0);
  });

  test('longest streak in a year ignores other years', () {
    final s = stats({
      '2025-12-31': 60,
      '2026-01-01': 60,
      '2026-01-02': 60,
      '2026-03-01': 60,
      '2026-03-02': 60,
      '2026-03-03': 60,
      '2026-03-04': 60,
    }, now);
    expect(s.longestStreakInYear(2026), 4);
    expect(s.longestStreakInYear(2025), 1);
  });

  test('weekday totals come out Monday first', () {
    final s = ListeningStats(
      totalTimeSeconds: 0,
      days: const {},
      weekdayTotals: const {'Monday': 1, 'Sunday': 7, 'Thursday': 4},
      todaySeconds: 0,
      recentSessions: const [],
      itemTimeListening: const {},
    );
    expect(s.weekdaySecondsMonFirst, [1, 0, 0, 4, 0, 0, 7]);
  });
}
