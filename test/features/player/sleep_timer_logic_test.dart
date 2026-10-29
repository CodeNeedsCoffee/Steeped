import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/player/data/sleep_timer_logic.dart';
import 'package:steeped/models/library_item_detail.dart';

void main() {
  group('autoRewindFor', () {
    test('off when base is 0', () {
      expect(
        autoRewindFor(
          pausedFor: const Duration(hours: 2),
          baseSeconds: 0,
          scaleUp: true,
        ),
        Duration.zero,
      );
    });

    test('brief pauses never rewind', () {
      expect(
        autoRewindFor(
          pausedFor: const Duration(seconds: 5),
          baseSeconds: 10,
          scaleUp: false,
        ),
        Duration.zero,
      );
    });

    test('fixed amount without scaling', () {
      expect(
        autoRewindFor(
          pausedFor: const Duration(hours: 3),
          baseSeconds: 10,
          scaleUp: false,
        ),
        const Duration(seconds: 10),
      );
    });

    test('scales up in steps and caps at two minutes', () {
      Duration f(Duration d, int base) =>
          autoRewindFor(pausedFor: d, baseSeconds: base, scaleUp: true);
      expect(f(const Duration(minutes: 1), 10), const Duration(seconds: 10));
      expect(f(const Duration(minutes: 10), 10), const Duration(seconds: 20));
      expect(f(const Duration(hours: 2), 10), const Duration(seconds: 30));
      expect(f(const Duration(hours: 2), 60), const Duration(seconds: 120));
    });
  });

  test('rewoundPosition is capped at the book start', () {
    expect(rewoundPosition(100, const Duration(seconds: 30)), 70);
    expect(rewoundPosition(10, const Duration(seconds: 30)), 0);
  });

  group('fadeVolume', () {
    const fade = Duration(seconds: 10);
    test('full volume before the fade begins', () {
      expect(fadeVolume(const Duration(seconds: 30), fade), 1.0);
      expect(fadeVolume(fade, fade), 1.0);
    });
    test('ramps linearly to zero', () {
      expect(fadeVolume(const Duration(seconds: 5), fade), 0.5);
      expect(fadeVolume(const Duration(seconds: 1), fade), closeTo(0.1, 1e-9));
      expect(fadeVolume(Duration.zero, fade), 0.0);
    });
    test('zero-length fade is a no-op', () {
      expect(fadeVolume(const Duration(seconds: 1), Duration.zero), 1.0);
    });
  });

  group('chapters', () {
    const chapters = [
      BookChapter(title: 'a', start: 0, end: 100),
      BookChapter(title: 'b', start: 100, end: 250),
    ];
    test('chapterEndAt finds the containing chapter', () {
      expect(chapterEndAt(50, chapters), 100);
      expect(chapterEndAt(100, chapters), 250);
      expect(chapterEndAt(250, chapters), isNull);
    });
    test('chapterTimeRemaining divides by speed', () {
      expect(
        chapterTimeRemaining(50, chapters, 1.0),
        const Duration(seconds: 50),
      );
      expect(
        chapterTimeRemaining(50, chapters, 2.0),
        const Duration(seconds: 25),
      );
      expect(chapterTimeRemaining(999, chapters, 1.0), isNull);
    });
  });

  group('isInAutoSleepWindow', () {
    const start = 22 * 60;
    const end = 6 * 60;
    test('crosses midnight', () {
      expect(isInAutoSleepWindow(23 * 60, start, end), isTrue);
      expect(isInAutoSleepWindow(2 * 60, start, end), isTrue);
      expect(isInAutoSleepWindow(6 * 60, start, end), isFalse);
      expect(isInAutoSleepWindow(12 * 60, start, end), isFalse);
      expect(isInAutoSleepWindow(22 * 60, start, end), isTrue);
    });
    test('same-day window', () {
      expect(isInAutoSleepWindow(13 * 60, 12 * 60, 14 * 60), isTrue);
      expect(isInAutoSleepWindow(15 * 60, 12 * 60, 14 * 60), isFalse);
    });
    test('equal bounds are an empty window', () {
      expect(isInAutoSleepWindow(0, 60, 60), isFalse);
    });
  });
}
