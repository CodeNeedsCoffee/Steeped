import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/ebook/data/pending_ebook_progress_store.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final t0 = DateTime(2026, 11, 12, 20);
  PendingEbookProgress p(String id, double f, DateTime at, {bool? fin}) =>
      PendingEbookProgress(
        itemId: id,
        location: 'epubcfi(/6/2)',
        fraction: f,
        at: at,
        isFinished: fin,
      );

  test('a failed position is kept, one per item, newest wins', () async {
    final s = PendingEbookProgressStore(db, profileId: 'p1');
    await s.put(p('a', 0.1, t0));
    await s.put(p('a', 0.2, t0.add(const Duration(seconds: 5))));
    await s.put(p('b', 0.5, t0));
    final all = {for (final e in await s.pending()) e.itemId: e};
    expect(all.length, 2);
    expect(all['a']!.fraction, 0.2);
  });

  test('delivered rows are removed', () async {
    final s = PendingEbookProgressStore(db);
    await s.put(p('a', 0.1, t0));
    await s.remove('a', sentAt: t0);
    expect(await s.pending(), isEmpty);
  });

  test('a position saved while the old one uploaded is not lost', () async {
    final s = PendingEbookProgressStore(db);
    await s.put(p('a', 0.1, t0));
    await s.put(p('a', 0.3, t0.add(const Duration(seconds: 10))));
    await s.remove('a', sentAt: t0); // the upload of the 0.1 row finished
    expect((await s.pending()).single.fraction, 0.3);
  });

  test('a finished flag survives a later position that does not set it', () async {
    final s = PendingEbookProgressStore(db);
    await s.put(p('a', 1.0, t0, fin: true));
    await s.put(p('a', 0.99, t0.add(const Duration(seconds: 1))));
    expect((await s.pending()).single.isFinished, isTrue);
  });

  test('rows are per profile', () async {
    await PendingEbookProgressStore(db, profileId: 'p1').put(p('a', 0.1, t0));
    expect(await PendingEbookProgressStore(db, profileId: 'p2').pending(), isEmpty);
  });
}
