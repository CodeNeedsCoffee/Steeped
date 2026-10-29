/// Bounds for a sleep-timer duration, in whole minutes. Mirrors
/// `playback_speed.dart`: the same normalize / step / parse / format shape,
/// so the sleep-timer sheet can behave like the speed sheet.
const int minSleepMinutes = 1;
const int maxSleepMinutes = 12 * 60;

/// One-tap durations, in minutes.
const List<int> sleepTimerPresets = [5, 10, 15, 30, 45, 60, 90];

/// Clamps into range.
int normalizeSleepMinutes(int value) =>
    value.clamp(minSleepMinutes, maxSleepMinutes);

/// Applies a stepper delta (±1 / ±5 / ±15) to [current].
int stepSleepMinutes(int current, int delta) =>
    normalizeSleepMinutes(current + delta);

/// Parses typed input into minutes.
///
/// Accepts a bare number of minutes (`45`), `h:mm` (`1:30`), unit forms
/// (`90m`, `1h`, `1h30m`, `1h 30`) and decimal hours (`1.5h`). Returns null
/// for anything unparseable *or* out of range rather than clamping, so a
/// mistyped `9999` is rejected instead of silently becoming 12 hours.
int? parseSleepMinutes(String input) {
  final text = input.trim().toLowerCase().replaceAll(',', '.');
  if (text.isEmpty) return null;

  int? minutes;

  final clock = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(text);
  final units = RegExp(
    r'^(?:(\d+(?:\.\d+)?)\s*h(?:ours?|rs?)?)?\s*(?:(\d+)\s*(?:m(?:in(?:ute)?s?)?)?)?$',
  ).firstMatch(text);

  if (clock != null) {
    final mins = int.parse(clock.group(2)!);
    if (mins >= 60) return null;
    minutes = int.parse(clock.group(1)!) * 60 + mins;
  } else if (units != null && text.contains(RegExp(r'\d'))) {
    final hours = double.tryParse(units.group(1) ?? '0') ?? 0;
    final mins = int.tryParse(units.group(2) ?? '0') ?? 0;
    minutes = (hours * 60).round() + mins;
  } else {
    return null;
  }

  if (minutes < minSleepMinutes || minutes > maxSleepMinutes) return null;
  return minutes;
}

/// `45` -> `"45 min"`, `60` -> `"1 h"`, `90` -> `"1 h 30 min"`.
String formatSleepMinutes(int minutes) {
  final value = normalizeSleepMinutes(minutes);
  final h = value ~/ 60;
  final m = value % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}
