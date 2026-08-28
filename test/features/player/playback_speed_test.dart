import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/player/data/playback_speed.dart';

void main() {
  group('normalizePlaybackSpeed', () {
    // The reason this function exists: stepping accumulates float error.
    test('rounds away accumulated floating-point error', () {
      expect(normalizePlaybackSpeed(1.3000000000000003), 1.3);
    });

    test('rounds to two decimal places', () {
      expect(normalizePlaybackSpeed(1.2549), 1.25);
      expect(normalizePlaybackSpeed(1.256), 1.26);
    });

    test('clamps to the supported range', () {
      expect(normalizePlaybackSpeed(0.1), minPlaybackSpeed);
      expect(normalizePlaybackSpeed(99), maxPlaybackSpeed);
    });
  });

  group('stepPlaybackSpeed', () {
    test('three +0.1 steps from 1.0 land exactly on 1.3', () {
      var speed = 1.0;
      for (var i = 0; i < 3; i++) {
        speed = stepPlaybackSpeed(speed, 0.1);
      }
      expect(speed, 1.3);
    });

    test('+0.25 from 1.0 lands on 1.25', () {
      expect(stepPlaybackSpeed(1.0, 0.25), 1.25);
    });

    test('mixed step sizes stay exact', () {
      expect(stepPlaybackSpeed(stepPlaybackSpeed(1.0, 0.25), 0.1), 1.35);
    });

    test('stepping down from 1.3 returns to 1.0', () {
      var speed = 1.3;
      for (var i = 0; i < 3; i++) {
        speed = stepPlaybackSpeed(speed, -0.1);
      }
      expect(speed, 1.0);
    });

    test('clamps rather than overshooting the bounds', () {
      expect(stepPlaybackSpeed(maxPlaybackSpeed, 0.25), maxPlaybackSpeed);
      expect(stepPlaybackSpeed(minPlaybackSpeed, -0.25), minPlaybackSpeed);
    });
  });

  group('parsePlaybackSpeed', () {
    test('parses a plain decimal', () {
      expect(parsePlaybackSpeed('1.3'), 1.3);
    });

    test('tolerates whitespace, a trailing x, and a comma separator', () {
      expect(parsePlaybackSpeed(' 1.3x '), 1.3);
      expect(parsePlaybackSpeed('1,3'), 1.3);
      expect(parsePlaybackSpeed('2X'), 2.0);
    });

    test('accepts the exact bounds', () {
      expect(parsePlaybackSpeed('0.5'), minPlaybackSpeed);
      expect(parsePlaybackSpeed('3'), maxPlaybackSpeed);
    });

    // Rejecting rather than clamping: a mistyped "13" must not become 3.0x.
    test('rejects values outside the range', () {
      expect(parsePlaybackSpeed('13'), isNull);
      expect(parsePlaybackSpeed('0.1'), isNull);
      expect(parsePlaybackSpeed('-1.3'), isNull);
    });

    test('rejects non-numeric input', () {
      expect(parsePlaybackSpeed(''), isNull);
      expect(parsePlaybackSpeed('   '), isNull);
      expect(parsePlaybackSpeed('abc'), isNull);
      expect(parsePlaybackSpeed('x'), isNull);
    });
  });

  group('formatPlaybackSpeed', () {
    test('trims trailing zeros', () {
      expect(formatPlaybackSpeed(1.0), '1x');
      expect(formatPlaybackSpeed(1.1), '1.1x');
      expect(formatPlaybackSpeed(1.3), '1.3x');
      expect(formatPlaybackSpeed(1.25), '1.25x');
      expect(formatPlaybackSpeed(2.0), '2x');
    });

    test('formats a drifted value cleanly', () {
      expect(formatPlaybackSpeed(1.3000000000000003), '1.3x');
    });
  });
}
