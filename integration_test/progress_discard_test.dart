// QOL_PLAN C1 verification, against the demo server (audiobooks.dev, demo/demo):
//   xvfb-run -a flutter test integration_test/progress_discard_test.dart -d linux
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:steeped/app.dart';
import 'package:steeped/core/audio/audio_handler_provider.dart';
import 'package:steeped/core/audio/steeped_audio_handler.dart';
import 'package:steeped/core/network/dio_client.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/library/state/library_providers.dart';
import 'package:steeped/features/player/state/playback_controller.dart';

Future<void> settle(WidgetTester t, [int secs = 8]) => t.pumpAndSettle(
  const Duration(milliseconds: 250),
  EnginePhase.sendSemanticsUpdate,
  Duration(seconds: secs),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('discard progress removes it on the server', (tester) async {
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
      UncontrolledProviderScope(
        container: container,
        child: const SteepedApp(),
      ),
    );
    await settle(tester, 3);
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

    final libs = await container.read(librariesProvider.future);
    final page = await container
        .read(libraryRepositoryProvider)
        .fetchLibraryItems(libs.first.id, page: 0);
    final item = page.items.firstWhere((i) => (i.duration ?? 0) > 60);

    final progressRepo = container.read(progressRepositoryProvider);
    await progressRepo.updateProgress(
      libraryItemId: item.id,
      currentTime: 30,
      duration: item.duration!,
    );

    final dio = container.read(dioProvider);
    final before = await dio.get<Map<String, dynamic>>(
      '/api/me/progress/${item.id}',
    );
    expect(before.data!['currentTime'], 30);

    await container
        .read(playbackControllerProvider.notifier)
        .discardProgress(libraryItemId: item.id);

    await expectLater(
      dio.get<Map<String, dynamic>>('/api/me/progress/${item.id}'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
  });
}
