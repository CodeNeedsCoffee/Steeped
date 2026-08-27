import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/library/state/library_providers.dart';

DownloadedItem item({
  required String itemId,
  String status = 'complete',
  String? libraryId = 'lib-1',
  double? progressCurrentTime,
  bool progressIsFinished = false,
  DateTime? createdAt,
}) {
  return DownloadedItem(
    itemId: itemId,
    serverUrl: 'https://example.test',
    title: itemId,
    authorNames: '',
    status: status,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    progressIsFinished: progressIsFinished,
    progressCurrentTime: progressCurrentTime,
    libraryId: libraryId,
  );
}

List<String> idsOf(List<DownloadedItem> items) =>
    items.map((i) => i.itemId).toList();

void main() {
  group('offlineContinueListeningItems', () {
    test('excludes finished items', () {
      final result = offlineContinueListeningItems([
        item(itemId: 'done', progressIsFinished: true),
        item(itemId: 'unfinished'),
      ], 'lib-1');

      expect(idsOf(result), ['unfinished']);
    });

    test('excludes items still downloading', () {
      final result = offlineContinueListeningItems([
        item(itemId: 'partial', status: 'downloading'),
        item(itemId: 'ready'),
      ], 'lib-1');

      expect(idsOf(result), ['ready']);
    });

    test('orders started items before unstarted ones', () {
      final result = offlineContinueListeningItems([
        item(itemId: 'unstarted'),
        item(itemId: 'started', progressCurrentTime: 120),
      ], 'lib-1');

      expect(idsOf(result), ['started', 'unstarted']);
    });

    test('orders newest download first within a bucket', () {
      final result = offlineContinueListeningItems([
        item(itemId: 'older', createdAt: DateTime(2026, 1, 1)),
        item(itemId: 'newer', createdAt: DateTime(2026, 6, 1)),
      ], 'lib-1');

      expect(idsOf(result), ['newer', 'older']);
    });

    // Rows written before DownloadedItems.libraryId existed have no library,
    // and hiding a genuinely downloaded book is worse than showing it under
    // the wrong one.
    test('always includes items with no recorded library', () {
      final result = offlineContinueListeningItems([
        item(itemId: 'untagged', libraryId: null),
      ], 'lib-1');

      expect(idsOf(result), ['untagged']);
    });

    test('excludes items belonging to another library', () {
      final result = offlineContinueListeningItems([
        item(itemId: 'other', libraryId: 'lib-2'),
        item(itemId: 'mine'),
      ], 'lib-1');

      expect(idsOf(result), ['mine']);
    });
  });
}
