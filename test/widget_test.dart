import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:steeped/app.dart';
import 'package:steeped/core/storage/app_database.dart';

void main() {
  testWidgets('SteepedApp builds and shows the splash screen', (
    WidgetTester tester,
  ) async {
    // Without this override, AppSettingsController's eager read pulls in
    // the real drift_flutter native (file + background isolate) executor,
    // which leaves an isolate-handshake Timer pending past the end of the
    // test and trips flutter_test's dangling-timer check. In-memory keeps
    // this test hermetic and avoids touching disk at all.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(
            AppDatabase.forTesting(NativeDatabase.memory()),
          ),
        ],
        child: const SteepedApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(SteepedApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
