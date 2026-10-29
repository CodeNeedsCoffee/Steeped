import '../../l10n/gen/app_localizations.dart';

/// "2h 5m" / "45m", localized. The one place listening/book durations are
/// turned into text, so every screen agrees.
String formatDurationText(AppLocalizations l10n, double seconds) {
  final totalMinutes = (seconds / 60).round();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return l10n.durationMinutes(minutes);
  return l10n.durationHoursMinutes(hours, minutes);
}
