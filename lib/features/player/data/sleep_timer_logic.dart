import '../../../models/library_item_detail.dart';

/// Pure helpers behind the sleep timer, auto-rewind and the auto sleep
/// window, kept free of Riverpod/audio so they unit-test directly.

/// How much to seek back when playback resumes after [pausedFor].
///
/// Pauses under 10 seconds (a notification blip, a headset tap) never
/// rewind. With [scaleUp] on, longer pauses rewind progressively further
/// (2x after 5 minutes, 3x after an hour), capped at two minutes.
Duration autoRewindFor({
  required Duration pausedFor,
  required int baseSeconds,
  required bool scaleUp,
}) {
  if (baseSeconds <= 0) return Duration.zero;
  if (pausedFor < const Duration(seconds: 10)) return Duration.zero;
  var seconds = baseSeconds;
  if (scaleUp) {
    if (pausedFor >= const Duration(hours: 1)) {
      seconds = baseSeconds * 3;
    } else if (pausedFor >= const Duration(minutes: 5)) {
      seconds = baseSeconds * 2;
    }
    if (seconds > 120) seconds = 120;
  }
  return Duration(seconds: seconds);
}

/// Position to land on after rewinding [rewind] from [position] (seconds),
/// never before the start of the book.
double rewoundPosition(double position, Duration rewind) {
  final target = position - rewind.inMilliseconds / 1000;
  return target < 0 ? 0 : target;
}

/// Player volume (0..1) while a fade-out is running. [remaining] is the
/// timer's time left; the ramp covers the last [fade]. Linear, floored at 0.
double fadeVolume(Duration remaining, Duration fade) {
  if (fade <= Duration.zero) return 1.0;
  if (remaining >= fade) return 1.0;
  if (remaining <= Duration.zero) return 0.0;
  return remaining.inMilliseconds / fade.inMilliseconds;
}

/// Wall-clock time left until the chapter containing [position] ends, at
/// playback [speed]. Null when no chapter contains [position].
Duration? chapterTimeRemaining(
  double position,
  List<BookChapter> chapters,
  double speed,
) {
  for (final c in chapters) {
    if (position >= c.start && position < c.end) {
      final s = speed <= 0 ? 1.0 : speed;
      return Duration(milliseconds: ((c.end - position) / s * 1000).round());
    }
  }
  return null;
}

/// Whether [nowMinutes] (minutes since midnight) falls in the window
/// [startMinutes, endMinutes). A window whose end is before its start
/// crosses midnight (e.g. 22:00 -> 06:00). Equal bounds mean "empty".
bool isInAutoSleepWindow(int nowMinutes, int startMinutes, int endMinutes) {
  if (startMinutes == endMinutes) return false;
  if (startMinutes < endMinutes) {
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }
  return nowMinutes >= startMinutes || nowMinutes < endMinutes;
}

/// End (global seconds) of the chapter containing [position], or null.
double? chapterEndAt(double position, List<BookChapter> chapters) {
  for (final c in chapters) {
    if (position >= c.start && position < c.end) return c.end;
  }
  return null;
}
