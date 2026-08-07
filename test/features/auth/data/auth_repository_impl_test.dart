import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/core/storage/token_storage.dart';
import 'package:pelekapro_mobile/features/auth/data/auth_remote_data_source.dart';
import 'package:pelekapro_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:pelekapro_mobile/features/auth/data/models/login_request.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_failure.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_session.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';
import 'package:pelekapro_mobile/features/auth/domain/driver_profile.dart';
import 'package:pelekapro_mobile/features/auth/domain/session_restore_result.dart';

void main() {
  group('AuthRepositoryImpl', () {
    test('stores a successful driver session securely', () async {
      final remote = _FakeAuthRemoteDataSource(session: _driverSession);
      final storage = _MemoryTokenStorage();
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      final session = await repository.login(
        login: '  +255700000000  ',
        password: 'safe-test-password',
      );

      expect(session.user.role, 'driver');
      expect(remote.lastRequest?.login, '+255700000000');
      expect(remote.lastRequest?.password, 'safe-test-password');
      expect(remote.lastRequest?.deviceName, 'PelekaPro Android');
      expect(storage.savedToken?.accessToken, 'server-token');
      expect(storage.savedToken?.tokenType, 'Bearer');
      expect(storage.savedToken?.expiresAt, _driverSession.expiresAt);
      expect(remote.revokedToken, isNull);
    });

    test('revokes and rejects a non-driver login', () async {
      final remote = _FakeAuthRemoteDataSource(
        session: _sessionForRole('manager'),
      );
      final storage = _MemoryTokenStorage();
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      await expectLater(
        repository.login(login: 'manager@example.com', password: 'password'),
        throwsA(
          isA<AuthFailure>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having(
                (error) => error.message,
                'message',
                contains('driver accounts'),
              ),
        ),
      );

      expect(remote.revokedToken, 'server-token');
      expect(storage.savedToken, isNull);
    });

    test('preserves API field errors for the login UI', () async {
      final remote = _FakeAuthRemoteDataSource(
        error: ApiException(
          message: 'Validation failed',
          statusCode: 422,
          fieldErrors: const {
            'login': ['The login field is required.'],
          },
        ),
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: _MemoryTokenStorage(),
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      await expectLater(
        repository.login(login: '', password: 'password'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.firstErrorFor('login'),
            'login error',
            'The login field is required.',
          ),
        ),
      );
    });

    test('revokes the token when secure storage fails', () async {
      final remote = _FakeAuthRemoteDataSource(session: _driverSession);
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: _MemoryTokenStorage(shouldFail: true),
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      await expectLater(
        repository.login(login: '+255700000000', password: 'password'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'message',
            contains('secure session could not be saved'),
          ),
        ),
      );

      expect(remote.revokedToken, 'server-token');
    });

    test('reports when no secure session exists', () async {
      final remote = _FakeAuthRemoteDataSource();
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: _MemoryTokenStorage(),
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      final result = await repository.restoreSession();

      expect(
        result,
        isA<UnavailableSession>().having(
          (session) => session.hadStoredSession,
          'hadStoredSession',
          isFalse,
        ),
      );
      expect(remote.currentUserToken, isNull);
    });

    test('restores a non-expired driver through auth me', () async {
      final remote = _FakeAuthRemoteDataSource(
        restoredUser: _driverSession.user,
      );
      final storage = _MemoryTokenStorage(
        initialToken: StoredAuthToken(
          accessToken: 'stored-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.parse('2026-09-05T10:30:00Z'),
        ),
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      final result = await repository.restoreSession();

      expect(
        result,
        isA<RestoredSession>().having(
          (session) => session.user.name,
          'user name',
          'Driver Name',
        ),
      );
      expect(remote.currentUserToken, 'stored-token');
      expect(storage.clearCount, 0);
    });

    test('clears an expired token without calling auth me', () async {
      final remote = _FakeAuthRemoteDataSource(
        restoredUser: _driverSession.user,
      );
      final storage = _MemoryTokenStorage(
        initialToken: StoredAuthToken(
          accessToken: 'expired-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.parse('2026-08-01T10:30:00Z'),
        ),
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      final result = await repository.restoreSession();

      expect(
        result,
        isA<UnavailableSession>().having(
          (session) => session.hadStoredSession,
          'hadStoredSession',
          isTrue,
        ),
      );
      expect(remote.currentUserToken, isNull);
      expect(storage.savedToken, isNull);
      expect(storage.clearCount, 1);
    });

    test('clears a token rejected by auth me with 401', () async {
      final remote = _FakeAuthRemoteDataSource(
        currentUserError: ApiException(
          message: 'Unauthenticated.',
          statusCode: 401,
        ),
      );
      final storage = _MemoryTokenStorage(
        initialToken: const StoredAuthToken(
          accessToken: 'revoked-token',
          tokenType: 'Bearer',
        ),
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      final result = await repository.restoreSession();

      expect(result, isA<UnavailableSession>());
      expect(remote.currentUserToken, 'revoked-token');
      expect(storage.savedToken, isNull);
      expect(storage.clearCount, 1);
    });

    test('keeps the token when auth me is temporarily unavailable', () async {
      final remote = _FakeAuthRemoteDataSource(
        currentUserError: ApiException(
          message: 'PelekaPro is temporarily unavailable. Please try again.',
          statusCode: 503,
        ),
      );
      const token = StoredAuthToken(
        accessToken: 'stored-token',
        tokenType: 'Bearer',
      );
      final storage = _MemoryTokenStorage(initialToken: token);
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      await expectLater(
        repository.restoreSession(),
        throwsA(
          isA<AuthFailure>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having(
                (error) => error.message,
                'message',
                contains('temporarily unavailable'),
              ),
        ),
      );

      expect(storage.savedToken, same(token));
      expect(storage.clearCount, 0);
    });

    test('revokes and clears a restored non-driver session', () async {
      final remote = _FakeAuthRemoteDataSource(
        restoredUser: _sessionForRole('manager').user,
      );
      final storage = _MemoryTokenStorage(
        initialToken: const StoredAuthToken(
          accessToken: 'manager-token',
          tokenType: 'Bearer',
        ),
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      final result = await repository.restoreSession();

      expect(
        result,
        isA<UnavailableSession>().having(
          (session) => session.hadStoredSession,
          'hadStoredSession',
          isTrue,
        ),
      );
      expect(remote.revokedToken, 'manager-token');
      expect(storage.savedToken, isNull);
      expect(storage.clearCount, 1);
    });

    test('logs out the current token and clears secure storage', () async {
      final remote = _FakeAuthRemoteDataSource();
      final storage = _MemoryTokenStorage(
        initialToken: const StoredAuthToken(
          accessToken: 'current-device-token',
          tokenType: 'Bearer',
        ),
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      await repository.logout();

      expect(remote.revokedToken, 'current-device-token');
      expect(storage.savedToken, isNull);
      expect(storage.clearCount, 1);
    });

    test('clears a token already rejected during logout', () async {
      final remote = _FakeAuthRemoteDataSource(
        logoutError: ApiException(message: 'Unauthenticated.', statusCode: 401),
      );
      final storage = _MemoryTokenStorage(
        initialToken: const StoredAuthToken(
          accessToken: 'already-revoked-token',
          tokenType: 'Bearer',
        ),
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      await repository.logout();

      expect(remote.revokedToken, 'already-revoked-token');
      expect(storage.savedToken, isNull);
      expect(storage.clearCount, 1);
    });

    test('keeps the token when logout temporarily fails', () async {
      final remote = _FakeAuthRemoteDataSource(
        logoutError: ApiException(
          message: 'PelekaPro is temporarily unavailable. Please try again.',
          statusCode: 503,
        ),
      );
      const token = StoredAuthToken(
        accessToken: 'retryable-token',
        tokenType: 'Bearer',
      );
      final storage = _MemoryTokenStorage(initialToken: token);
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
        now: _now,
      );

      await expectLater(
        repository.logout(),
        throwsA(
          isA<AuthFailure>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having(
                (error) => error.message,
                'message',
                contains('temporarily unavailable'),
              ),
        ),
      );

      expect(remote.revokedToken, 'retryable-token');
      expect(storage.savedToken, same(token));
      expect(storage.clearCount, 0);
    });
  });
}

class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  _FakeAuthRemoteDataSource({
    this.session,
    this.error,
    this.restoredUser,
    this.currentUserError,
    this.logoutError,
  });

  final AuthSession? session;
  final ApiException? error;
  final AuthUser? restoredUser;
  final ApiException? currentUserError;
  final ApiException? logoutError;
  LoginRequest? lastRequest;
  String? revokedToken;
  String? currentUserToken;

  @override
  Future<AuthSession> login(LoginRequest request) async {
    lastRequest = request;

    if (error case final error?) {
      throw error;
    }

    return session!;
  }

  @override
  Future<void> logout(String accessToken) async {
    revokedToken = accessToken;

    if (logoutError case final error?) {
      throw error;
    }
  }

  @override
  Future<AuthUser> currentUser(String accessToken) async {
    currentUserToken = accessToken;

    if (currentUserError case final error?) {
      throw error;
    }

    return restoredUser!;
  }

  @override
  void close() {}
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({this.shouldFail = false, StoredAuthToken? initialToken})
    : savedToken = initialToken;

  final bool shouldFail;
  StoredAuthToken? savedToken;
  int clearCount = 0;

  @override
  Future<void> save(StoredAuthToken token) async {
    if (shouldFail) {
      throw StateError('Simulated secure storage failure.');
    }

    savedToken = token;
  }

  @override
  Future<StoredAuthToken?> read() async => savedToken;

  @override
  Future<void> clear() async {
    clearCount += 1;
    savedToken = null;
  }
}

DateTime _now() => DateTime.parse('2026-08-06T10:30:00Z');

final _driverSession = AuthSession(
  accessToken: 'server-token',
  tokenType: 'Bearer',
  expiresAt: DateTime.parse('2026-09-05T10:30:00Z'),
  user: const AuthUser(
    id: 42,
    businessId: 7,
    branchId: 3,
    name: 'Driver Name',
    phone: '+255700000000',
    email: 'driver@example.com',
    status: 'active',
    role: 'driver',
    driverProfile: DriverProfile(
      id: 9,
      isAvailable: true,
      currentStatus: 'available',
    ),
  ),
);

AuthSession _sessionForRole(String role) {
  return AuthSession(
    accessToken: 'server-token',
    tokenType: 'Bearer',
    user: AuthUser(
      id: 42,
      businessId: 7,
      name: 'Account User',
      status: 'active',
      role: role,
    ),
  );
}
