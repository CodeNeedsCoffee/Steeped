import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/library/data/library_cache_repository.dart';
import 'package:steeped/models/library.dart';

void main() {
  late AppDatabase db;
  late LibraryCacheRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LibraryCacheRepository(db);
  });

  tearDown(() => db.close());

  group('LibraryCacheRepository', () {
    test('returns empty when nothing has been cached', () async {
      expect(await repository.load(), isEmpty);
    });

    test('round-trips a saved library list', () async {
      await repository.save(const [
        Library(
          id: 'lib-1',
          name: 'Audio Books',
          mediaType: 'book',
          icon: 'database',
          displayOrder: 1,
        ),
        Library(
          id: 'lib-2',
          name: 'Podcasts',
          mediaType: 'podcast',
          icon: 'podcast',
          displayOrder: 2,
        ),
      ]);

      final loaded = await repository.load();

      expect(loaded.map((l) => l.id), ['lib-1', 'lib-2']);
      expect(loaded.last.isPodcastLibrary, isTrue);
    });

    test('overwrites the previous cache rather than appending', () async {
      const first = Library(
        id: 'lib-1',
        name: 'First',
        mediaType: 'book',
        icon: 'database',
        displayOrder: 1,
      );
      const second = Library(
        id: 'lib-2',
        name: 'Second',
        mediaType: 'book',
        icon: 'database',
        displayOrder: 1,
      );

      await repository.save(const [first]);
      await repository.save(const [second]);

      expect((await repository.load()).map((l) => l.id), ['lib-2']);
    });
  });
}
