import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/streaks/streak.dart';

// "Today" is Wed 2026-11-11.
final now = DateTime(2026, 11, 11, 15);

Map<String, double> listen(List<String> days, [double s = 600]) => {
  for (final d in days) d: s,
};

StreakResult run(
  List<String> listened, {
  List<String> read = const [],
  StreakRules rules = const StreakRules(),
  Map<String, double>? listening,
}) => computeStreak(
  listening: listening ?? listen(listened),
  reading: {for (final d in read) d: 600},
  rules: rules,
  now: now,
);

void main() {
  const noForgive = StreakRules(forgiveMissedDay: false);

  test('no history is no streak', () {
    final r = computeStreak(
      listening: {},
      reading: {},
      rules: const StreakRules(),
      now: now,
    );
    expect(r.current, 0);
    expect(r.atRisk, isFalse);
  });

  test('consecutive days ending today', () {
    final r = run(['2026-11-09', '2026-11-10', '2026-11-11'], rules: noForgive);
    expect(r.current, 3);
    expect(r.todayDone, isTrue);
    expect(r.atRisk, isFalse);
  });

  test('empty today keeps the streak but is at risk', () {
    final r = run(['2026-11-09', '2026-11-10'], rules: noForgive);
    expect(r.current, 2);
    expect(r.todayDone, isFalse);
    expect(r.atRisk, isTrue);
  });

  test('reading alone counts, and merges with listening', () {
    final r = run(
      ['2026-11-10'],
      read: ['2026-11-09', '2026-11-11'],
      rules: noForgive,
    );
    expect(r.current, 3);
  });

  test('a goal needs listening + reading to reach it', () {
    const goal = StreakRules(thresholdSeconds: 900, forgiveMissedDay: false);
    final r = computeStreak(
      listening: {'2026-11-10': 600, '2026-11-11': 1000},
      reading: {'2026-11-10': 400},
      rules: goal,
      now: now,
    );
    expect(r.current, 2); // 600 + 400 reaches 900
    final r2 = computeStreak(
      listening: {'2026-11-10': 600, '2026-11-11': 1000},
      reading: {},
      rules: goal,
      now: now,
    );
    expect(r2.current, 1); // yesterday fell short
  });

  test('without forgiveness one missed day resets', () {
    final r = run([
      '2026-11-07',
      '2026-11-08',
      '2026-11-10',
      '2026-11-11',
    ], rules: noForgive);
    expect(r.current, 2);
    expect(r.longest, 2);
  });

  test('forgiveness bridges one missed day without counting it', () {
    final r = run(['2026-11-07', '2026-11-08', '2026-11-10', '2026-11-11']);
    expect(r.current, 4);
    expect(r.savedDays, 1);
  });

  test('two missed days in a row break even with forgiveness', () {
    final r = run(['2026-11-06', '2026-11-07', '2026-11-10', '2026-11-11']);
    expect(r.current, 2);
  });

  test('a second bridge inside 7 days is not allowed', () {
    // Misses on the 5th and the 8th: the second is only 3 days after the first.
    final r = run([
      '2026-11-03',
      '2026-11-04',
      '2026-11-06',
      '2026-11-07',
      '2026-11-09',
      '2026-11-10',
      '2026-11-11',
    ]);
    expect(r.current, 3);
  });

  test('a bridge is allowed again after 7 days', () {
    final r = run([
      '2026-11-01', '2026-11-03', // miss the 2nd
      '2026-11-04',
      '2026-11-05',
      '2026-11-06',
      '2026-11-07',
      '2026-11-08',
      '2026-11-09',
      '2026-11-11', // miss the 10th, 8 days after the first bridge
    ]);
    expect(r.current, 9);
    expect(r.savedDays, 2);
  });

  test('yesterday missed with forgiveness: streak holds, today at risk', () {
    final r = run(['2026-11-08', '2026-11-09']);
    expect(r.current, 2);
    expect(r.atRisk, isTrue);
  });

  test('server one day ahead: listening under tomorrow counts as today', () {
    final r = run(
      const [],
      listening: {'2026-11-10': 600, '2026-11-11': 600, '2026-11-12': 600},
      rules: noForgive,
    );
    expect(r.todayDone, isTrue);
    expect(r.current, 3);
  });

  test('longest streak is all-time', () {
    final r = run([
      '2026-01-01',
      '2026-01-02',
      '2026-01-03',
      '2026-01-04',
      '2026-11-11',
    ], rules: noForgive);
    expect(r.longest, 4);
    expect(r.current, 1);
  });

  test('weekly: one active day per week keeps it going', () {
    const weekly = StreakRules(weekly: true);
    // Weeks starting Oct 26, Nov 2, Nov 9 (this week).
    final r = run(['2026-10-28', '2026-11-05', '2026-11-11'], rules: weekly);
    expect(r.current, 3);
    expect(r.todayDone, isTrue);
  });

  test(
    'weekly: an empty past week breaks it, an empty current week does not',
    () {
      const weekly = StreakRules(weekly: true);
      expect(
        run(['2026-10-20', '2026-11-05', '2026-11-11'], rules: weekly).current,
        2,
      );
      final open = run(['2026-10-28', '2026-11-05'], rules: weekly);
      expect(open.current, 2);
      expect(open.atRisk, isTrue);
    },
  );

  test('recent shows the last 7 days, today last', () {
    final r = run(['2026-11-05', '2026-11-08', '2026-11-11'], rules: noForgive);
    expect(r.recent, [true, false, false, true, false, false, true]);
  });

  test('milestones: the largest newly reached one, once', () {
    int? m(int cur, int last, {bool weekly = false}) =>
        milestoneToCelebrate(current: cur, lastCelebrated: last, weekly: weekly);
    expect(m(6, 0), isNull);
    expect(m(7, 0), 7);
    expect(m(7, 7), isNull);
    expect(m(31, 7), 30);
    expect(m(40, 30), isNull);
    expect(m(3, 30), isNull); // streak restarted below the old milestone
    expect(m(7, 30), 7); // and reaching 7 again is celebrated again
    expect(m(4, 0, weekly: true), 4);
  });
}
