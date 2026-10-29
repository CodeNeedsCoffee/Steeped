import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/player/data/pending_sync_repository.dart';

void main() {
  late AppDatabase db;
  late PendingSyncRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PendingSyncRepository(db);
  });
  tearDown(() => db.close());

  test('pending count tracks enqueue, overwrite and remove', () async {
    final counts = <int>[];
    final sub = repo.watchPendingCount().listen(counts.add);
    await Future<void>.delayed(Duration.zero);

    await repo.enqueue(libraryItemId: 'a', currentTime: 1, duration: 10);
    await repo.enqueue(libraryItemId: 'b', currentTime: 2, duration: 10);
    // Same item again replaces its row rather than adding one.
    await repo.enqueue(libraryItemId: 'a', currentTime: 5, duration: 10);
    await repo.remove('b', null);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(counts.first, 0);
    expect(counts.last, 1);
    expect(counts, contains(2));
    await sub.cancel();
  });
}
