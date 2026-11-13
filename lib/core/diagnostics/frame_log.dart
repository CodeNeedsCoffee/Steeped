import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:flutter/scheduler.dart';

/// In debug and profile builds, logs every frame that took longer than
/// [slowMillis] with how it splits between building (Dart, the UI thread) and
/// rasterising (the GPU thread), so a lag report can be answered from
/// `adb logcat -s flutter | grep "\[frame\]"`. Does nothing in release builds.
void startFrameLog({int slowMillis = 32}) {
  if (kReleaseMode) return;
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      final total = t.totalSpan.inMilliseconds;
      if (total < slowMillis) continue;
      debugPrint(
        '[frame] total=${total}ms build=${t.buildDuration.inMilliseconds}ms '
        'raster=${t.rasterDuration.inMilliseconds}ms',
      );
    }
  });
}
