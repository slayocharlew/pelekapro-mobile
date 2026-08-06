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

void main() {
  group('AuthRepositoryImpl', () {
    test('stores a successful driver session securely', () async {
      final remote = _FakeAuthRemoteDataSource(session: _driverSession);
      final storage = _MemoryTokenStorage();
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        deviceName: 'PelekaPro Android',
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
  });
}

class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  _FakeAuthRemoteDataSource({this.session, this.error});

  final AuthSession? session;
  final ApiException? error;
  LoginRequest? lastRequest;
  String? revokedToken;

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
  }

  @override
  void close() {}
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({this.shouldFail = false});

  final bool shouldFail;
  StoredAuthToken? savedToken;

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
    savedToken = null;
  }
}

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
