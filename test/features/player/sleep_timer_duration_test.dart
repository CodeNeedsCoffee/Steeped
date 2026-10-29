import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/player/data/sleep_timer_duration.dart';

void main() {
  group('normalizeSleepMinutes', () {
    test('clamps to the supported range', () {
      expect(normalizeSleepMinutes(0), minSleepMinutes);
      expect(normalizeSleepMinutes(-5), minSleepMinutes);
      expect(normalizeSleepMinutes(99999), maxSleepMinutes);
      expect(normalizeSleepMinutes(30), 30);
    });
  });

  group('stepSleepMinutes', () {
    test('steps up and down', () {
      expect(stepSleepMinutes(30, 5), 35);
      expect(stepSleepMinutes(30, -15), 15);
    });

    test('stops at the bounds', () {
      expect(stepSleepMinutes(minSleepMinutes, -5), minSleepMinutes);
      expect(stepSleepMinutes(maxSleepMinutes, 15), maxSleepMinutes);
    });
  });

  group('parseSleepMinutes', () {
    test('bare number is minutes', () {
      expect(parseSleepMinutes('45'), 45);
      expect(parseSleepMinutes('  7 '), 7);
    });

    test('h:mm', () {
      expect(parseSleepMinutes('1:30'), 90);
      expect(parseSleepMinutes('0:45'), 45);
      expect(parseSleepMinutes('1:75'), isNull);
    });

    test('unit forms', () {
      expect(parseSleepMinutes('90m'), 90);
      expect(parseSleepMinutes('90 min'), 90);
      expect(parseSleepMinutes('2h'), 120);
      expect(parseSleepMinutes('1h30m'), 90);
      expect(parseSleepMinutes('1h 30'), 90);
    });

    test('decimal hours, dot or comma', () {
      expect(parseSleepMinutes('1.5h'), 90);
      expect(parseSleepMinutes('1,5h'), 90);
    });

    test('rejects junk and out-of-range values', () {
      expect(parseSleepMinutes(''), isNull);
      expect(parseSleepMinutes('abc'), isNull);
      expect(parseSleepMinutes('h'), isNull);
      expect(parseSleepMinutes('0'), isNull);
      expect(parseSleepMinutes('9999'), isNull);
      expect(parseSleepMinutes('13h'), isNull);
      expect(parseSleepMinutes('-5'), isNull);
    });

    test('accepts the bounds', () {
      expect(parseSleepMinutes('1'), 1);
      expect(parseSleepMinutes('12h'), maxSleepMinutes);
    });
  });

  group('formatSleepMinutes', () {
    test('formats minutes, hours and both', () {
      expect(formatSleepMinutes(45), '45 min');
      expect(formatSleepMinutes(60), '1 h');
      expect(formatSleepMinutes(90), '1 h 30 min');
    });
  });
}
