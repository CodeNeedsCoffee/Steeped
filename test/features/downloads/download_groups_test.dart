import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/downloads/download_groups.dart';

DownloadedItem item(String id, String profile, String server) => DownloadedItem(
  itemId: id,
  serverUrl: server,
  title: id,
  authorNames: '',
  status: 'complete',
  createdAt: DateTime(2026),
  progressIsFinished: false,
  profileId: profile,
);

void main() {
  final items = [
    item('o1', 'B', 'https://b.test'),
    item('a1', 'A', 'https://a.test'),
    item('a2', 'A', 'https://a.test'),
    item('legacy', '', 'https://old.test'),
  ];

  List<String> keys(List<DownloadGroup> g) => g.map((e) => e.key).toList();

  test('online: active server first, others after', () {
    final g = groupDownloads(
      items,
      activeProfileId: 'A',
      offline: false,
      showOtherServers: true,
    );
    expect(keys(g).first, 'A');
    expect(g.first.isActive, isTrue);
    expect(g.first.items.map((i) => i.itemId), ['a1', 'a2']);
    expect(keys(g), containsAll(['B', 'url:https://old.test']));
  });

  test('online with the setting off hides other servers', () {
    final g = groupDownloads(
      items,
      activeProfileId: 'A',
      offline: false,
      showOtherServers: false,
    );
    expect(keys(g), ['A']);
  });

  test('offline shows every download regardless of the setting', () {
    final g = groupDownloads(
      items,
      activeProfileId: 'A',
      offline: true,
      showOtherServers: false,
    );
    expect(g.expand((x) => x.items), hasLength(4));
  });

  test('no active profile: nothing is marked active', () {
    final g = groupDownloads(
      items,
      activeProfileId: null,
      offline: true,
      showOtherServers: true,
    );
    expect(g.any((x) => x.isActive), isFalse);
  });
}
