/// G7: when (and whether) the next streak reminder fires. Pure, so the rules
/// are testable: off by default, one a day at most, never once the day is
/// done, nothing without a streak to keep, nothing in quiet hours, and none
/// after several ignored in a row.
library;

import 'streak.dart' show dayKey;

const quietStartMinutes = 22 * 60;
const quietEndMinutes = 8 * 60;
const maxIgnoredReminders = 3;

bool _inQuietHours(int minutes) =>
    minutes >= quietStartMinutes || minutes < quietEndMinutes;

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

/// The next reminder time, or null for none.
DateTime? nextReminderTime({
  required bool enabled,
  required int minutesOfDay,
  required bool quietHours,
  required bool todayDone,
  required int currentStreak,
  required int ignoredInARow,
  required DateTime now,
}) {
  if (!enabled || currentStreak <= 0 || ignoredInARow >= maxIgnoredReminders) {
    return null;
  }
  var day = DateTime(now.year, now.month, now.day);
  var candidate = _at(day, minutesOfDay);
  // Today's slot is gone if it has passed (or is about to) or the day is done.
  if (todayDone || !candidate.isAfter(now.add(const Duration(minutes: 1)))) {
    day = DateTime(day.year, day.month, day.day + 1);
    candidate = _at(day, minutesOfDay);
  }
  if (quietHours && _inQuietHours(minutesOfDay)) {
    // A time inside quiet hours moves to when they end.
    var end = _at(day, quietEndMinutes);
    if (!end.isAfter(candidate)) end = _at(DateTime(day.year, day.month, day.day + 1), quietEndMinutes);
    candidate = end;
  }
  return candidate;
}

/// How many of the most recent past days had a reminder scheduled and no
/// activity. [reminded] holds `YYYY-MM-DD` keys; [recent] is the last 7 days'
/// activity (oldest first, today last).
int ignoredReminders({
  required Set<String> reminded,
  required List<bool> recent,
  required DateTime today,
}) {
  var count = 0;
  for (var back = 1; back < recent.length; back++) {
    final day = DateTime(today.year, today.month, today.day - back);
    final active = recent[recent.length - 1 - back];
    if (!reminded.contains(dayKey(day)) || active) break;
    count++;
  }
  return count;
}
