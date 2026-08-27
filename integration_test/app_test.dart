// End-to-end smoke test driven against the real public Audiobookshelf demo
// server (https://audiobooks.dev, public-domain content, demo/demo login --
// see https://github.com/advplyr/audiobookshelf), so it exercises the real
// dio/session/router stack rather than mocks. All assertions are structural
// (find.text / find.byType) -- no screenshots involved, so failures point at
// exactly which step and which widget broke.
//
// Runs on the "linux" target (see linux/README.md -- test harness only, not
// a shipped platform) rather than an Android emulator/device, so this builds
// the widget tree directly instead of calling the real app main():
// audio_service and background_downloader (initialized in main.dart) don't
// have Linux implementations, and this test never touches playback or
// downloads, so a plain SteepedAudioHandler() and an in-memory database
// (same pattern as test/widget_test.dart) stand in for them.
//
//   flutter test integration_test/app_test.dart -d linux
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

const testServerUrl = 'https://audiobooks.dev';
const testUsername = 'demo';
const testPassword = 'demo';
// Public demo library content -- if this ever fails only because the demo
// server's catalog changed, check https://audiobooks.dev/audiobookshelf
// directly and swap in a current title rather than assuming a real regression.
const seededBookTitle = 'The Invisible Man';
// Same "Audiobooks" library on audiobooks.dev -- a real multi-book series,
// confirmed live via GET /api/libraries/:id/series.
const seededSeriesName = 'Moral Letters';
const seededSeriesBookTitle = 'Moral Letters, Vol. I';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connect, log in, and see a real library item', (tester) async {
    // The Linux target's secure storage is the real OS keyring (via
    // libsecret), not an in-memory fake -- unlike the drift database
    // override below, a session saved by a previous run of this same test
    // persists across runs and would let SessionController's bootstrap
    // skip straight past the Connect Server screen. Clear it first so
    // every run starts from a genuinely logged-out state.
    await const FlutterSecureStorage().deleteAll();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(
            AppDatabase.forTesting(NativeDatabase.memory()),
          ),
          audioHandlerProvider.overrideWithValue(SteepedAudioHandler()),
        ],
        child: const SteepedApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // --- Connect Server screen ---
    expect(find.text('Connect to Server'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Server address'),
      testServerUrl,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // --- Login screen ---
    expect(find.text('Log In'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextField, 'Username'),
      testUsername,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      testPassword,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // --- Home tab: a known real item must be visible somewhere. ---
    expect(
      find.text(seededBookTitle),
      findsOneWidget,
      reason:
          'Expected a known audiobooks.dev library item to render after '
          'login. If this fails, check whether login succeeded (look for '
          'an error Text widget) before assuming the library grid itself '
          'is broken.',
    );

    // --- Series tab: PLAN.md 4.10/4.5 -- a real cover-bearing series card,
    // not the old plain-text _LabelCard placeholder. ---
    await tester.tap(find.text('Series'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(
      find.text(seededSeriesName),
      findsWidgets,
      reason:
          'Expected the Series tab to list a real series by name. If this '
          'fails, check for an error Text widget (grid failed to load) '
          'before assuming the tab itself is missing.',
    );

    // --- Series detail: tapping the card should show its real books, ---
    // --- fetched once as part of the series list, no second request. ---
    await tester.tap(find.text(seededSeriesName).first);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(seededSeriesBookTitle), findsOneWidget);

    // --- Search: PLAN.md 4.7 (partial: Books + Series). ---
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Invisible');
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(find.text('Books'), findsOneWidget);
    expect(find.text(seededBookTitle), findsOneWidget);
  });
}
