/// Bounds for playback rate. Below 0.5x speech stops being intelligible and
/// above 3.0x time-stretching artifacts dominate, so these are the range the
/// UI offers rather than anything the player itself enforces.
const double minPlaybackSpeed = 0.5;
const double maxPlaybackSpeed = 3.0;

/// One-tap speeds. Includes 1.1 and 1.3 because those are the rates actually
/// listened at — the old dropdown's fixed 0.25 grid couldn't express either.
const List<double> playbackSpeedPresets = [0.75, 1.0, 1.1, 1.3, 1.5, 2.0];

/// Rounds to 2dp and clamps into range.
///
/// Every path that produces a speed goes through this. Repeated stepping
/// accumulates binary floating-point error — `1.0 + 0.1 + 0.1 + 0.1` is
/// `1.3000000000000003`, not `1.3` — which would otherwise be persisted to
/// settings and rendered verbatim in the UI.
double normalizePlaybackSpeed(double value) {
  final rounded = (value * 100).round() / 100;
  return rounded.clamp(minPlaybackSpeed, maxPlaybackSpeed).toDouble();
}

/// Applies a stepper delta (±0.1 / ±0.25) to [current].
double stepPlaybackSpeed(double current, double delta) =>
    normalizePlaybackSpeed(current + delta);

/// Parses typed input — tolerates surrounding whitespace, a trailing `x`,
/// and a comma decimal separator.
///
/// Returns null for anything unparseable *or* out of range, rather than
/// clamping: a mistyped `13` should be rejected outright, not silently
/// accepted as 3.0x.
double? parsePlaybackSpeed(String input) {
  final cleaned = input
      .trim()
      .toLowerCase()
      .replaceAll('x', '')
      .replaceAll(',', '.')
      .trim();
  if (cleaned.isEmpty) return null;

  final parsed = double.tryParse(cleaned);
  if (parsed == null) return null;
  if (parsed < minPlaybackSpeed || parsed > maxPlaybackSpeed) return null;

  return normalizePlaybackSpeed(parsed);
}

/// `1.3` -> `"1.3x"`, `1.25` -> `"1.25x"`, `1.0` -> `"1x"`. Trailing zeros
/// are trimmed so a 2dp value doesn't render as "1.30x" beside "1.1x".
String formatPlaybackSpeed(double value) {
  final normalized = normalizePlaybackSpeed(value);
  var text = normalized.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceAll(RegExp(r'0+$'), '');
    text = text.replaceAll(RegExp(r'\.$'), '');
  }
  return '${text}x';
}
