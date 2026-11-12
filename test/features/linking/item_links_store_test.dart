import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/linking/item_links_store.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const link = ItemLink(
    audioItemId: 'a1',
    ebookItemId: 'e1',
    source: LinkSource.auto,
  );

  test('save, find from either side, remove', () async {
    final store = ItemLinksStore(db, profileId: 'p1');
    expect(await store.forItem('a1'), isNull);
    await store.save(link);
    expect((await store.forItem('a1'))?.ebookItemId, 'e1');
    expect((await store.forItem('e1'))?.audioItemId, 'a1');
    expect(link.otherSide('a1'), 'e1');
    expect(link.otherSide('e1'), 'a1');
    await store.remove('e1');
    expect(await store.forItem('a1'), isNull);
  });

  test('relinking replaces the old link for either item', () async {
    final store = ItemLinksStore(db);
    await store.save(link);
    await store.save(
      const ItemLink(
        audioItemId: 'a1',
        ebookItemId: 'e2',
        source: LinkSource.manual,
      ),
    );
    final all = await store.load();
    expect(all, hasLength(1));
    expect(all.single.ebookItemId, 'e2');
    expect(all.single.source, LinkSource.manual);
  });

  test('links are per profile', () async {
    await ItemLinksStore(db, profileId: 'p1').save(link);
    expect(await ItemLinksStore(db, profileId: 'p2').forItem('a1'), isNull);
  });
}
