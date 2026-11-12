import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/streaks/reading_days_store.dart';

void main() {
  final t0 = DateTime(2026, 11, 11, 20);

  test('touches inside the idle window earn the gap', () {
    final c = ReadingClock();
    c.touch(t0);
    c.touch(t0.add(const Duration(seconds: 40)));
    c.touch(t0.add(const Duration(seconds: 100)));
    expect(c.takePending(), 100);
    expect(c.takePending(), 0);
  });

  test('a gap longer than the idle window earns nothing', () {
    final c = ReadingClock();
    c.touch(t0);
    c.touch(t0.add(const Duration(minutes: 30))); // book left on a table
    c.touch(t0.add(const Duration(minutes: 30, seconds: 20)));
    expect(c.takePending(), 20);
  });

  test('rapid touches add up instead of flooring to zero', () {
    final c = ReadingClock();
    for (var i = 0; i <= 200; i++) {
      c.touch(t0.add(Duration(milliseconds: i * 100)));
    }
    expect(c.takePending(), 20);
  });

  test('pause forgets the last touch', () {
    final c = ReadingClock();
    c.touch(t0);
    c.pause();
    c.touch(t0.add(const Duration(seconds: 30)));
    expect(c.takePending(), 0);
  });

  test('the store adds per day and per profile', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final a = ReadingDaysStore(db, profileId: 'p1');
    await a.add(t0, 60);
    await a.add(t0, 30);
    await a.add(t0.add(const Duration(days: 1)), 10);
    await a.add(t0, 0);
    expect(await a.load(), {'2026-11-11': 90, '2026-11-12': 10});
    expect(await ReadingDaysStore(db, profileId: 'p2').load(), isEmpty);
  });
}
