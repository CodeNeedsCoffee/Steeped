// LIBRARY_PLAN.md verification, run in the Linux app against the public demo
// server (https://audiobooks.dev, demo/demo):
//   xvfb-run -a flutter test integration_test/library_features_test.dart -d linux
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:steeped/app.dart';
import 'package:steeped/core/audio/audio_handler_provider.dart';
import 'package:steeped/core/audio/steeped_audio_handler.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/library/state/library_providers.dart';
import 'package:steeped/models/library_query.dart';

Future<void> settle(WidgetTester t, [int secs = 8]) =>
    t.pumpAndSettle(const Duration(milliseconds: 250), EnginePhase.sendSemanticsUpdate, Duration(seconds: secs));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('library: sub-filter, sort, filter, playlists, authors, search', (tester) async {
    await const FlutterSecureStorage().deleteAll();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory())),
      audioHandlerProvider.overrideWithValue(SteepedAudioHandler()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SteepedApp()));
    await settle(tester, 3);

    await tester.enterText(find.widgetWithText(TextField, 'Server address'), 'https://audiobooks.dev');
    await tester.tap(find.text('Continue'));
    await settle(tester, 10);
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'demo');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'demo');
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await settle(tester, 10);

    // ---- Library tab with sub-filter
    await tester.tap(find.text('Library'));
    await settle(tester);
    for (final s in ['Books', 'Authors', 'Collections', 'Playlists']) {
      expect(find.text(s), findsWidgets, reason: 'sub-filter "$s"');
    }
    expect(find.byTooltip('Sort'), findsOneWidget);
    expect(find.byTooltip('Filter'), findsOneWidget);

    final libId = container.read(selectedLibraryIdProvider) ??
        (await container.read(librariesProvider.future)).first.id;

    // ---- Sort: pick "Date added", state + persistence
    await tester.tap(find.byTooltip('Sort'));
    await settle(tester);
    await tester.tap(find.text('Date added').last, warnIfMissed: false);
    await settle(tester);
    var q = container.read(libraryQueryProvider(libId));
    expect(q.sort, LibrarySort.addedAt);
    expect(container.read(libraryItemsProvider(libId)).items, isNotEmpty);
    final saved = await container.read(libraryQueryStoreProvider).load(libId);
    expect(saved.sort, LibrarySort.addedAt, reason: 'sort remembered');

    // ---- Direction toggle reloads with desc
    await tester.tap(find.byTooltip('Ascending'));
    await settle(tester);
    expect(container.read(libraryQueryProvider(libId)).desc, isTrue);

    // ---- Filter by progress: not started -> chip
    await tester.tap(find.byTooltip('Filter'));
    await settle(tester);
    await tester.tap(find.text('Progress'));
    await settle(tester);
    await tester.tap(find.text('Not started'));
    await settle(tester);
    expect(find.textContaining('Progress: Not started'), findsOneWidget);
    expect(container.read(libraryQueryProvider(libId)).filterParam, startsWith('progress.'));
    await tester.tap(find.text('Clear all'));
    await settle(tester);
    expect(container.read(libraryQueryProvider(libId)).hasFilter, isFalse);

    // ---- Grid/list toggle
    await tester.tap(find.byTooltip('List view'));
    await settle(tester);
    expect(find.byType(ListTile), findsWidgets, reason: 'list mode renders ListTiles');
    await tester.tap(find.byTooltip('Grid view'));
    await settle(tester);

    // ---- Quick actions: long-press a book tile
    final firstTitle = container.read(libraryItemsProvider(libId)).items.first.title;
    await tester.longPress(find.text(firstTitle).first);
    await settle(tester);
    for (final a in ['Play', 'Details', 'Download', 'Add to playlist']) {
      expect(find.text(a), findsWidgets, reason: 'quick action "$a"');
    }
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    // ---- Authors
    await tester.tap(find.text('Authors').last);
    await settle(tester);
    final authors = await container.read(libraryRepositoryProvider).fetchAuthors(libId);
    expect(authors, isNotEmpty);
    await tester.tap(find.text(authors.first.name).first);
    await settle(tester);
    expect(find.text(authors.first.name), findsWidgets);
    await tester.pageBack();
    await settle(tester);

    // ---- Collections load (read-only unless permitted)
    await tester.tap(find.text('Collections').last);
    await settle(tester);
    expect(find.textContaining('Failed to load'), findsNothing);

    // ---- Playlists: create, add via quick actions, reorder, delete
    final repo = container.read(libraryRepositoryProvider);
    await tester.tap(find.text('Playlists').last);
    await settle(tester);
    await tester.tap(find.text('New playlist'));
    await settle(tester);
    final name = 'zz-steeped-test-${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(find.byType(TextField).last, name);
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settle(tester);
    expect(find.text(name), findsOneWidget);

    final created = (await repo.fetchPlaylists(libId)).firstWhere((p) => p.name == name);
    try {
      final books = container.read(libraryItemsProvider(libId)).items.take(2).toList();
      expect(books.length, 2);
      await repo.addToPlaylist(created.id, books[0].id);
      await repo.addToPlaylist(created.id, books[1].id);
      var p = await repo.fetchPlaylist(created.id);
      expect(p.items.map((i) => i.libraryItemId), [books[0].id, books[1].id]);
      await repo.reorderPlaylist(created.id, p.items.reversed.toList());
      p = await repo.fetchPlaylist(created.id);
      expect(p.items.map((i) => i.libraryItemId), [books[1].id, books[0].id], reason: 'server honored reorder');
      await repo.removeFromPlaylist(created.id, books[0].id);
      p = await repo.fetchPlaylist(created.id);
      expect(p.items.length, 1);

      // UI: open the playlist, see the item
      container.invalidate(playlistsProvider(libId));
      await settle(tester);
      await tester.tap(find.text(name));
      await settle(tester);
      expect(find.text(p.items.first.title), findsWidgets);
      await tester.pageBack();
      await settle(tester);
    } finally {
      await repo.deletePlaylist(created.id);
    }

    // ---- Search upgrade: back to Home, search, recent searches
    await tester.tap(find.text('Home'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Invisible');
    for (var i = 0; i < 30 && find.text('Books').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Books'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(container.read(recentSearchesProvider), contains('Invisible'));
  });
}
