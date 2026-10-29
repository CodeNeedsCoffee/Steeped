import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/auth/data/server_profile_repository.dart';
import 'package:steeped/features/auth/state/session_controller.dart';
import 'package:steeped/features/auth/state/session_state.dart';

String _snap(String name) => jsonEncode({
  'id': 'id-$name',
  'username': name,
  'type': 'user',
  'isActive': true,
  'permissions': {'download': true},
});

Future<void> _until(ProviderContainer c, bool Function(SessionState) ok) async {
  for (var i = 0; i < 200; i++) {
    if (ok(c.read(sessionControllerProvider))) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('session never reached the expected state: '
      '${c.read(sessionControllerProvider)}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    // Two signed-in accounts on legacy-token servers (no refresh calls).
    FlutterSecureStorage.setMockInitialValues({
      'session.activeProfile': 'a',
      'profile:a:serverUrl': 'https://one.test',
      'profile:a:legacyToken': 'tok-a',
      'profile:a:userSnapshot': _snap('alice'),
      'profile:b:serverUrl': 'https://two.test',
      'profile:b:legacyToken': 'tok-b',
      'profile:b:userSnapshot': _snap('bob'),
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = ServerProfileRepository(db);
    await repo.upsert(
      id: 'a',
      serverUrl: 'https://one.test',
      username: 'alice',
      lastUsedAt: 1,
    );
    await repo.upsert(
      id: 'b',
      serverUrl: 'https://two.test',
      username: 'bob',
      lastUsedAt: 2,
    );
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  SessionAuthenticated authed() =>
      container.read(sessionControllerProvider) as SessionAuthenticated;

  test('boots into the last active profile', () async {
    container.read(sessionControllerProvider);
    await _until(container, (s) => s is SessionAuthenticated);
    expect(authed().profileId, 'a');
    expect(authed().serverUrl, 'https://one.test');
    expect(container.read(activeProfileIdProvider), 'a');
  });

  test('switchTo restores the other account with its own server and token', () async {
    container.read(sessionControllerProvider);
    await _until(container, (s) => s is SessionAuthenticated);

    await container.read(sessionControllerProvider.notifier).switchTo('b');
    expect(authed().profileId, 'b');
    expect(authed().serverUrl, 'https://two.test');
    expect(authed().user.effectiveToken, 'tok-b');

    await container.read(sessionControllerProvider.notifier).switchTo('a');
    expect(authed().user.effectiveToken, 'tok-a');
  });

  test('removing the active account falls back to another and leaves it intact', () async {
    container.read(sessionControllerProvider);
    await _until(container, (s) => s is SessionAuthenticated);
    final notifier = container.read(sessionControllerProvider.notifier);

    await notifier.removeProfile('a');
    expect(authed().profileId, 'b');
    expect(authed().user.effectiveToken, 'tok-b');
    expect((await ServerProfileRepository(db).all()).map((p) => p.id), ['b']);
  });

  test('logging out the last account signs out completely', () async {
    container.read(sessionControllerProvider);
    await _until(container, (s) => s is SessionAuthenticated);
    final notifier = container.read(sessionControllerProvider.notifier);

    await notifier.logout(); // removes a -> b becomes active
    expect(authed().profileId, 'b');
    await notifier.logout();
    expect(container.read(sessionControllerProvider), isA<SessionUnauthenticated>());
    expect(await ServerProfileRepository(db).all(), isEmpty);
  });

  test('switching to the already-active account does nothing', () async {
    container.read(sessionControllerProvider);
    await _until(container, (s) => s is SessionAuthenticated);
    final before = container.read(sessionControllerProvider);
    await container.read(sessionControllerProvider.notifier).switchTo('a');
    expect(identical(container.read(sessionControllerProvider), before), isTrue);
  });
}
