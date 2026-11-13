import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/streaks/streak_providers.dart';

void main() {
  test('reading while audio plays earns no extra minutes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var playing = false;
    final t = ReadingTracker(container, audioPlaying: () => playing);
    final start = DateTime(2026, 11, 13, 10);
    t.touch(at: start);
    t.touch(at: start.add(const Duration(seconds: 30)));
    expect(t.clock.takePending(), 30);

    playing = true;
    t.touch(at: start.add(const Duration(seconds: 60)));
    t.touch(at: start.add(const Duration(seconds: 90)));
    expect(t.clock.takePending(), 0);

    // Audio stops: the first touch only restarts the clock.
    playing = false;
    t.touch(at: start.add(const Duration(seconds: 120)));
    t.touch(at: start.add(const Duration(seconds: 140)));
    expect(t.clock.takePending(), 20);
    await t.close();
  });
}
