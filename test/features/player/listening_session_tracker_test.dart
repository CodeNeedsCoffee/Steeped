import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/app_database.dart';
import 'package:steeped/features/player/data/listening_session_repository.dart';
import 'package:steeped/features/player/state/listening_session_tracker.dart';

class _FakeApi extends ListeningSessionRepository {
  _FakeApi() : super(Dio());

  final calls = <String>[];
  final sent = <double>[];
  bool failing = false;
  int opened = 0;

  @override
  Future<String> open(SessionItem item) async {
    if (failing) throw DioException(requestOptions: RequestOptions());
    opened++;
    calls.add('open ${item.libraryItemId}');
    return 'sid$opened';
  }

  @override
  Future<void> sync(
    String sessionId, {
    required double timeListened,
    required double currentTime,
    required double duration,
  }) async {
    if (failing) throw DioException(requestOptions: RequestOptions());
    calls.add('sync $sessionId');
    sent.add(timeListened);
  }

  @override
  Future<void> close(
    String sessionId, {
    required double timeListened,
    required double currentTime,
    required double duration,
  }) async {
    if (failing) throw DioException(requestOptions: RequestOptions());
    calls.add('close $sessionId');
    sent.add(timeListened);
  }
}

void main() {
  late AppDatabase db;
  late _FakeApi api;
  late PendingListeningSessionRepository pending;
  late ListeningSessionTracker tracker;
  late DateTime clock;
  var online = true;
  var ended = 0;
  var activeProfile = 'p1';
  var keys = 0;

  const bookA = SessionItem(
    libraryItemId: 'a',
    title: 'A',
    duration: 1000,
  );
  const bookB = SessionItem(
    libraryItemId: 'b',
    title: 'B',
    duration: 1000,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _FakeApi();
    pending = PendingListeningSessionRepository(db, profileId: 'p1');
    clock = DateTime(2026, 10, 30, 12);
    online = true;
    ended = 0;
    activeProfile = 'p1';
    keys = 0;
    tracker = ListeningSessionTracker(
      apiOf: () => api,
      pendingOf: () => pending,
      hasNetwork: () async => online,
      activeProfileId: () => activeProfile,
      onSessionEnded: () => ended++,
      now: () => clock,
      newKey: () => 'k${keys++}',
    );
  });

  tearDown(() => db.close());

  void advance(int seconds) => clock = clock.add(Duration(seconds: seconds));

  test('sends only time spent playing, opening the session once', () async {
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    tracker.setPlaying(true);
    advance(20);
    await tracker.tick(100);
    tracker.setPlaying(false);
    advance(300); // paused: must not count
    tracker.setPlaying(true);
    advance(15);
    await tracker.tick(120);

    expect(api.calls, ['open a', 'sync sid1', 'sync sid1']);
    expect(api.sent, [20.0, 15.0]);
    expect(api.opened, 1);
  });

  test('a tick with under a second listened sends nothing', () async {
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    await tracker.tick(0);
    expect(api.calls, isEmpty);
  });

  test('end closes with the remaining time and reports', () async {
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    tracker.setPlaying(true);
    advance(10);
    await tracker.tick(50);
    advance(5);
    await tracker.end(60);

    expect(api.calls, ['open a', 'sync sid1', 'close sid1']);
    expect(api.sent, [10.0, 5.0]);
    expect(ended, 1);
    expect(await pending.pending(), isEmpty);
  });

  test('attaching another item closes the previous one', () async {
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    tracker.setPlaying(true);
    advance(12);
    tracker.attach(bookB, itemKey: 'b', ownerProfileId: 'p1');
    await Future<void>.delayed(Duration.zero);
    advance(8);
    await tracker.tick(10);

    expect(api.calls, contains('close sid1'));
    expect(api.sent, [12.0, 8.0]);
  });

  test('attaching the same item again is a no-op', () async {
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    tracker.setPlaying(true);
    advance(10);
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    await tracker.tick(10);
    expect(api.sent, [10.0]);
  });

  test('offline time is queued, then delivered once back online', () async {
    online = false;
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    tracker.setPlaying(true);
    advance(40);
    await tracker.tick(40);

    final rows = await pending.pending();
    expect(rows.single.timeListening, 40);
    expect(rows.single.sessionKey, 'k0');
    expect(api.calls, isEmpty);

    online = true;
    advance(20);
    await tracker.tick(60);
    // The whole 60s goes in the first sync, and the queued row is dropped.
    expect(api.sent, [60.0]);
    expect(await pending.pending(), isEmpty);
  });

  test('a failed sync keeps the time for the next attempt', () async {
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    tracker.setPlaying(true);
    advance(15);
    await tracker.tick(15);
    api.failing = true;
    advance(15);
    await tracker.tick(30);
    expect((await pending.pending()).single.timeListening, 15);

    api.failing = false;
    advance(15);
    await tracker.tick(45);
    expect(api.sent, [15.0, 30.0]);
    expect(await pending.pending(), isEmpty);
  });

  test('a failed close leaves the time queued for upload', () async {
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    tracker.setPlaying(true);
    advance(30);
    api.failing = true;
    await tracker.end(30);
    expect((await pending.pending()).single.timeListening, 30);
    expect(ended, 1);
  });

  test('an item owned by another profile is queued, not sent', () async {
    activeProfile = 'p2';
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    tracker.setPlaying(true);
    advance(25);
    await tracker.tick(25);
    expect(api.calls, isEmpty);
    expect((await pending.pending()).single.profileId, 'p1');
  });

  test('time before the item was attached does not count', () async {
    tracker.setPlaying(true);
    advance(500);
    tracker.attach(bookA, itemKey: 'a', ownerProfileId: 'p1');
    advance(7);
    await tracker.tick(7);
    expect(api.sent, [7.0]);
  });
}
