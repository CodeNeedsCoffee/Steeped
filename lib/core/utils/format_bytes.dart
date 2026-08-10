/// Human-readable byte size, e.g. `340 MB`, `1.2 GB`. Used by the Phase 6.10
/// storage-management UI for per-item and total download sizes.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1024;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final precision = value < 10 ? 1 : 0;
  return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
}
