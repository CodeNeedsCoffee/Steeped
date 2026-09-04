import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/storage/session_storage.dart';
import 'package:steeped/features/auth/data/auth_repository.dart';
import 'package:steeped/features/auth/data/token_refresh_coordinator.dart';
import 'package:steeped/models/auth_user.dart';
import 'package:steeped/models/login_result.dart';
import 'package:steeped/models/user_permissions.dart';

AuthUser _buildUser({String? accessToken, String? refreshToken}) {
  return AuthUser(
    id: 'user-1',
    username: 'evan',
    email: '',
    type: 'user',
    legacyToken: null,
    isOldToken: false,
    accessToken: accessToken,
    refreshToken: refreshToken,
    isActive: true,
    isLocked: false,
    hasOpenIDLink: false,
    permissions: const UserPermissions(
      download: true,
      update: false,
      delete: false,
      upload: false,
      createEreader: false,
      accessAllLibraries: true,
      accessAllTags: true,
      accessExplicitContent: false,
      selectedTagsNotAccessible: false,
      librariesAccessible: [],
      itemTagsSelected: [],
    ),
  );
}

/// Overrides `refresh` instead of hitting the network — mirrors the
/// subclass-based fake convention used elsewhere in this test suite (see
/// `library_cache_repository_test.dart`) rather than pulling in a mocking
/// package.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.delay = Duration.zero});

  final Duration delay;
  int callCount = 0;

  /// When set, `refresh` throws this instead of returning a result.
  Object? failure;

  /// The user returned by a successful `refresh` call.
  AuthUser result = _buildUser(
    accessToken: 'access-2',
    refreshToken: 'refresh-2',
  );

  @override
  Future<LoginResult> refresh({
    required String serverUrl,
    required String refreshToken,
  }) async {
    callCount++;
    if (delay > Duration.zero) await Future.delayed(delay);
    final failure = this.failure;
    if (failure != null) throw failure;
    return LoginResult(
      user: result,
      userDefaultLibraryId: null,
      serverSettings: const {},
    );
  }
}

class _FakeSessionStorage extends SessionStorage {
  _FakeSessionStorage(this._refreshToken) : super(const FlutterSecureStorage());

  String? _refreshToken;
  int saveCount = 0;
  String? lastSavedAccessToken;
  String? lastSavedRefreshToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> saveRefreshedTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    saveCount++;
    lastSavedAccessToken = accessToken;
    lastSavedRefreshToken = refreshToken;
    _refreshToken = refreshToken;
  }
}

void main() {
  group('TokenRefreshCoordinator', () {
    test('coalesces concurrent callers into a single network call', () async {
      final repository = _FakeAuthRepository(
        delay: const Duration(milliseconds: 50),
      );
      final storage = _FakeSessionStorage('refresh-1');
      final coordinator = TokenRefreshCoordinator(
        authRepository: repository,
        sessionStorage: storage,
      );

      final results = await Future.wait([
        coordinator.refresh(serverUrl: 'https://example.com'),
        coordinator.refresh(serverUrl: 'https://example.com'),
        coordinator.refresh(serverUrl: 'https://example.com'),
      ]);

      expect(repository.callCount, 1);
      expect(storage.saveCount, 1);
      expect(results.map((u) => u.accessToken), everyElement('access-2'));
    });

    test('starts a fresh call after the in-flight refresh completes', () async {
      final repository = _FakeAuthRepository();
      final storage = _FakeSessionStorage('refresh-1');
      final coordinator = TokenRefreshCoordinator(
        authRepository: repository,
        sessionStorage: storage,
      );

      await coordinator.refresh(serverUrl: 'https://example.com');
      await coordinator.refresh(serverUrl: 'https://example.com');

      expect(repository.callCount, 2);
    });

    test('propagates a failure to every concurrent waiter, then retries clean', () async {
      final repository = _FakeAuthRepository(
        delay: const Duration(milliseconds: 20),
      )..failure = StateError('server rejected refresh token');
      final storage = _FakeSessionStorage('refresh-1');
      final coordinator = TokenRefreshCoordinator(
        authRepository: repository,
        sessionStorage: storage,
      );

      final first = coordinator.refresh(serverUrl: 'https://example.com');
      final second = coordinator.refresh(serverUrl: 'https://example.com');

      await expectLater(first, throwsStateError);
      await expectLater(second, throwsStateError);
      expect(repository.callCount, 1);
      expect(storage.saveCount, 0);

      // A later call isn't stuck replaying the cached rejection.
      repository.failure = null;
      final user = await coordinator.refresh(serverUrl: 'https://example.com');
      expect(user.accessToken, 'access-2');
      expect(repository.callCount, 2);
    });

    test('throws when no refresh token is in storage', () async {
      final repository = _FakeAuthRepository();
      final storage = _FakeSessionStorage(null);
      final coordinator = TokenRefreshCoordinator(
        authRepository: repository,
        sessionStorage: storage,
      );

      await expectLater(
        coordinator.refresh(serverUrl: 'https://example.com'),
        throwsStateError,
      );
      expect(repository.callCount, 0);
    });
  });
}
