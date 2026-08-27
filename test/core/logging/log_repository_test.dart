import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/logging/log_repository.dart';
import 'package:steeped/core/storage/app_database.dart';

void main() {
  late AppDatabase db;
  late LogRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LogRepository(db);
  });

  tearDown(() => db.close());

  Future<List<LogEntry>> allEntries() =>
      (db.select(db.logEntries)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  group('repeat collapsing', () {
    test('folds consecutive identical entries into one counted row', () async {
      for (var i = 0; i < 5; i++) {
        await repository.log('warning', 'socket', 'Failed host lookup');
      }

      final entries = await allEntries();
      expect(entries, hasLength(1));
      expect(entries.single.repeatCount, 5);
    });

    test('a differing field starts a new row', () async {
      await repository.log('warning', 'socket', 'Failed host lookup');
      await repository.log('warning', 'socket', 'Different message');
      await repository.log('error', 'socket', 'Different message');
      await repository.log('error', 'sync', 'Different message');

      final entries = await allEntries();
      expect(entries, hasLength(4));
      expect(entries.every((e) => e.repeatCount == 1), isTrue);
    });

    test('the same message recurring later gets its own row', () async {
      await repository.log('warning', 'socket', 'Failed host lookup');
      await repository.log('info', 'socket', 'Connected');
      await repository.log('warning', 'socket', 'Failed host lookup');

      final entries = await allEntries();
      expect(entries, hasLength(3));
      expect(entries.last.repeatCount, 1);
    });

    test('a repeat advances the timestamp to the latest occurrence', () async {
      await repository.log('warning', 'socket', 'Failed host lookup');
      final first = (await allEntries()).single.timestamp;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.log('warning', 'socket', 'Failed host lookup');
      final second = (await allEntries()).single.timestamp;

      expect(second.isAfter(first) || second.isAtSameMomentAs(first), isTrue);
    });
  });

  group('purgeOldEntries', () {
    Future<void> insertAged(String message, Duration age) {
      return db
          .into(db.logEntries)
          .insert(
            LogEntriesCompanion.insert(
              level: 'warning',
              tag: 'test',
              message: message,
              timestamp: Value(DateTime.now().subtract(age)),
            ),
          );
    }

    test('drops entries older than the retention period', () async {
      await insertAged('ancient', LogRepository.retentionPeriod * 2);
      await insertAged('recent', const Duration(hours: 1));

      final deleted = await repository.purgeOldEntries();

      expect(deleted, 1);
      expect((await allEntries()).single.message, 'recent');
    });

    test('keeps everything when nothing has aged out', () async {
      await insertAged('recent', const Duration(hours: 1));

      expect(await repository.purgeOldEntries(), 0);
      expect(await allEntries(), hasLength(1));
    });
  });
}
