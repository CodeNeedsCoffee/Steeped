// QOL_PLAN Phase D verification, against the demo server (audiobooks.dev, demo/demo):
//   xvfb-run -a flutter test integration_test/library_qol_test.dart -d linux
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
import 'package:steeped/features/library/author_book_order.dart';
import 'package:steeped/features/settings/state/settings_providers.dart';

Future<void> settle(WidgetTester t, [int secs = 8]) =>
    t.pumpAndSettle(const Duration(milliseconds: 250), EnginePhase.sendSemanticsUpdate, Duration(seconds: secs));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('library QoL: section memory, ebook filter, collapse, author order', (tester) async {
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

    await tester.tap(find.text('Library'));
    await settle(tester);
    final libId = container.read(selectedLibraryIdProvider) ??
        (await container.read(librariesProvider.future)).first.id;

    // ---- D1: section is remembered in the saved query
    await tester.tap(find.text('Authors').last);
    await settle(tester);
    expect(container.read(libraryQueryProvider(libId)).section, 'authors');
    final saved = await container.read(libraryQueryStoreProvider).load(libId);
    expect(saved.section, 'authors', reason: 'section persisted');
    expect(find.byTooltip('Sort'), findsNothing, reason: 'Authors view has no books toolbar');

    await tester.tap(find.text('Books').last);
    await settle(tester);
    expect((await container.read(libraryQueryStoreProvider).load(libId)).section, 'books');

    // ---- D2: has-ebook filter
    await tester.tap(find.byTooltip('Filter'));
    await settle(tester);
    await tester.tap(find.text('Ebook'));
    await settle(tester);
    await tester.tap(find.text('Has ebook'));
    await settle(tester);
    expect(find.textContaining('Ebook: Has ebook'), findsOneWidget);
    var q = container.read(libraryQueryProvider(libId));
    expect(q.filterParam, startsWith('ebooks.'));
    final withEbook = container.read(libraryItemsProvider(libId));
    expect(withEbook.error, isNull);
    for (final i in withEbook.items) {
      expect(i.hasEbook, isTrue, reason: '${i.title} should have an ebook');
    }
    await tester.tap(find.text('Clear all'));
    await settle(tester);

    // ---- D5: collapse series toggle reloads with collapseseries
    await tester.tap(find.byTooltip('Collapse series'));
    await settle(tester);
    expect(container.read(appSettingsProvider).valueOrNull?.collapseSeries, isTrue);
    expect(find.byTooltip('Show every book'), findsOneWidget);
    final collapsed = container.read(libraryItemsProvider(libId));
    expect(collapsed.error, isNull);
    final collapsedTiles = collapsed.items.where((i) => i.collapsedSeries != null).toList();
    // The collapsed list never shows more tiles than the plain one.
    await tester.tap(find.byTooltip('Show every book'));
    await settle(tester);
    expect(container.read(libraryItemsProvider(libId)).total, greaterThanOrEqualTo(collapsed.total));
    if (collapsedTiles.isNotEmpty) {
      debugPrint('collapsed series tiles: ${collapsedTiles.length}');
    }

    // ---- D4: author page ordering over real data
    final authors = await container.read(libraryRepositoryProvider).fetchAuthors(libId);
    for (final summary in authors.take(8)) {
      final a = await container.read(libraryRepositoryProvider).fetchAuthor(summary.id);
      final ordered = authorBooksInReadingOrder(a);
      expect(ordered.length, a.books.length, reason: '${a.name}: nothing lost or duplicated');
      expect(ordered.map((b) => b.id).toSet().length, ordered.length);
    }

    // ---- D3: Go to author in quick actions
    final first = container.read(libraryItemsProvider(libId)).items.firstWhere((i) => i.authorOrPublisherName != null);
    await tester.longPress(find.text(first.title).first);
    await settle(tester);
    expect(find.text('Go to author'), findsOneWidget);
    await tester.tap(find.text('Go to author'));
    await settle(tester, 10);
    expect(find.byType(CustomScrollView), findsWidgets, reason: 'author page opened');
  });
}
