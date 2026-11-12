import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/streaks/reminder_plan.dart';

// Thu 2026-11-12, 15:00.
final now = DateTime(2026, 11, 12, 15);

DateTime? plan({
  bool enabled = true,
  int minutes = 19 * 60,
  bool quiet = true,
  bool todayDone = false,
  int streak = 4,
  int ignored = 0,
  DateTime? at,
}) => nextReminderTime(
  enabled: enabled,
  minutesOfDay: minutes,
  quietHours: quiet,
  todayDone: todayDone,
  currentStreak: streak,
  ignoredInARow: ignored,
  now: at ?? now,
);

void main() {
  test('off by default means nothing is scheduled', () {
    expect(plan(enabled: false), isNull);
  });

  test("today's slot when it is still ahead and the day is not done", () {
    expect(plan(), DateTime(2026, 11, 12, 19));
  });

  test('once the day is done the reminder moves to tomorrow', () {
    expect(plan(todayDone: true), DateTime(2026, 11, 13, 19));
  });

  test('a slot that has passed moves to tomorrow', () {
    expect(plan(at: DateTime(2026, 11, 12, 20)), DateTime(2026, 11, 13, 19));
  });

  test('no streak, no reminder', () {
    expect(plan(streak: 0), isNull);
  });

  test('a time in quiet hours moves to when they end', () {
    expect(plan(minutes: 23 * 60), DateTime(2026, 11, 13, 8));
    expect(plan(minutes: 6 * 60, at: DateTime(2026, 11, 12, 4)), DateTime(2026, 11, 12, 8));
  });

  test('quiet hours can be turned off', () {
    expect(plan(minutes: 23 * 60, quiet: false), DateTime(2026, 11, 12, 23));
  });

  test('stops after three ignored reminders in a row', () {
    expect(plan(ignored: 2), isNotNull);
    expect(plan(ignored: 3), isNull);
  });

  test('ignored count: consecutive reminded, inactive past days', () {
    final today = DateTime(2026, 11, 12);
    // recent = last 7 days, today last: inactive on the 9th,10th,11th; active the 8th.
    final recent = [false, false, true, false, false, false, false];
    final reminded = {'2026-11-11', '2026-11-10', '2026-11-09', '2026-11-08'};
    expect(ignoredReminders(reminded: reminded, recent: recent, today: today), 3);
  });

  test('a day without a reminder, or with activity, ends the run', () {
    final today = DateTime(2026, 11, 12);
    final recent = [false, false, false, false, false, false, false];
    expect(ignoredReminders(reminded: {'2026-11-10'}, recent: recent, today: today), 0);
    expect(
      ignoredReminders(
        reminded: {'2026-11-11', '2026-11-10'},
        recent: [false, false, false, false, true, false, false],
        today: today,
      ),
      1,
    );
  });
}
