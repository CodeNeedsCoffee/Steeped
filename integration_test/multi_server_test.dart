// QOL_PLAN E2 verification. Needs a second Audiobookshelf server on
// 127.0.0.1:3399 with user second/secondpw and a library (see the plan:
// run the local checkout with `node index.js`), plus the public demo
// server (audiobooks.dev, demo/demo):
//   xvfb-run -a flutter test integration_test/multi_server_test.dart -d linux
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:steeped/app.dart';
import 'package:steeped/core/audio/audio_handler_provider.dart';
import 'package:steeped/core/audio/steeped_audio_handler.dart';
import 'package:steeped/core/router/app_router.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/auth/data/server_profile_repository.dart';
import 'package:steeped/features/downloads/state/download_controller.dart';
import 'package:steeped/features/auth/state/profile_switcher.dart';
import 'package:steeped/features/auth/state/session_controller.dart';
import 'package:steeped/features/auth/state/session_state.dart';
import 'package:steeped/features/library/state/library_providers.dart';

Future<void> settle(WidgetTester t, [int secs = 8]) => t.pumpAndSettle(
  const Duration(milliseconds: 250),
  EnginePhase.sendSemanticsUpdate,
  Duration(seconds: secs),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two servers stay separate and switching works', (tester) async {
    await const FlutterSecureStorage().deleteAll();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(
          AppDatabase.forTesting(NativeDatabase.memory()),
        ),
        audioHandlerProvider.overrideWithValue(SteepedAudioHandler()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SteepedApp()),
    );
    await settle(tester, 3);

    // ---- account 1: the demo server
    await tester.enterText(
      find.widgetWithText(TextField, 'Server address'),
      'https://audiobooks.dev',
    );
    await tester.tap(find.text('Continue'));
    await settle(tester, 10);
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'demo');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'demo');
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await settle(tester, 10);

    SessionAuthenticated authed() =>
        container.read(sessionControllerProvider) as SessionAuthenticated;
    final demoProfile = authed().profileId;
    final demoLibs = await container.read(librariesProvider.future);
    expect(demoLibs, isNotEmpty);
    container.read(recentSearchesProvider);
    await settle(tester, 2);
    await container.read(recentSearchesProvider.notifier).add('demo-term');
    await settle(tester, 2);
    expect(container.read(recentSearchesProvider), contains('demo-term'));

    // ---- account 2: the local server, via the real "add" flow
    container.read(appRouterProvider).push('/add-server');
    await settle(tester, 3);
    await tester.enterText(
      find.widgetWithText(TextField, 'Server address'),
      'http://127.0.0.1:3399',
    );
    await tester.tap(find.text('Continue'));
    await settle(tester, 10);
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'second');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secondpw');
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await settle(tester, 10);

    final secondProfile = authed().profileId;
    expect(secondProfile, isNot(demoProfile));
    expect(authed().serverUrl, contains('127.0.0.1:3399'));

    final profiles = await container.read(serverProfileRepositoryProvider).all();
    expect(profiles.map((p) => p.id).toSet(), {demoProfile, secondProfile});
    expect(profiles.map((p) => p.username), contains('second'));

    // Library list and search history are the second server's, not demo's.
    final secondLibs = await container.read(librariesProvider.future);
    expect(secondLibs.map((l) => l.name), contains('Second Lib'));
    expect(secondLibs.map((l) => l.id).toSet().intersection(
      demoLibs.map((l) => l.id).toSet(),
    ), isEmpty);
    await settle(tester, 2);
    expect(container.read(recentSearchesProvider), isNot(contains('demo-term')));
    container.read(recentSearchesProvider);
    await settle(tester, 2);
    await container.read(recentSearchesProvider.notifier).add('second-term');

    // Downloads are tagged with the account they were made under.
    expect(container.read(downloadRepositoryProvider).profileId, secondProfile);

    // ---- switch back to demo
    await container.read(profileSwitcherProvider).switchTo(demoProfile);
    await settle(tester, 10);
    expect(authed().profileId, demoProfile);
    final backLibs = await container.read(librariesProvider.future);
    expect(backLibs.map((l) => l.name), isNot(contains('Second Lib')));
    container.read(recentSearchesProvider);
    await settle(tester, 2);
    expect(container.read(recentSearchesProvider), contains('demo-term'));
    expect(container.read(recentSearchesProvider), isNot(contains('second-term')));

    // ...and to second again.
    await container.read(profileSwitcherProvider).switchTo(secondProfile);
    await settle(tester, 10);
    expect(authed().serverUrl, contains('127.0.0.1:3399'));
    container.read(recentSearchesProvider);
    await settle(tester, 2);
    expect(container.read(recentSearchesProvider), contains('second-term'));

    // ---- forgetting one account leaves the other signed in
    await container.read(profileSwitcherProvider).removeProfile(
      secondProfile,
      deleteDownloads: true,
    );
    await settle(tester, 10);
    expect(authed().profileId, demoProfile);
    expect(
      (await container.read(serverProfileRepositoryProvider).all()).single.id,
      demoProfile,
    );
  });
}
