import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/core/storage/token_storage.dart';
import 'package:pelekapro_mobile/features/auth/data/auth_remote_data_source.dart';
import 'package:pelekapro_mobile/features/auth/data/models/login_request.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_failure.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_session.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';
import 'package:pelekapro_mobile/features/auth/domain/session_restore_result.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.tokenStorage,
    required this.deviceName,
    required this.now,
  });

  final AuthRemoteDataSource remoteDataSource;
  final TokenStorage tokenStorage;
  final String deviceName;
  final DateTime Function() now;

  @override
  Future<SessionRestoreResult> restoreSession() async {
    late final StoredAuthToken? storedToken;

    try {
      storedToken = await tokenStorage.read();
    } on Object {
      throw AuthFailure(
        message:
            'The secure session could not be read. Restart the app and try again.',
      );
    }

    if (storedToken == null) {
      return const UnavailableSession(hadStoredSession: false);
    }

    final expiresAt = storedToken.expiresAt;

    if (expiresAt != null && !expiresAt.toUtc().isAfter(now().toUtc())) {
      await _clearStoredSession();
      return const UnavailableSession(hadStoredSession: true);
    }

    late final AuthUser user;

    try {
      user = await remoteDataSource.currentUser(storedToken.accessToken);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearStoredSession();
        return const UnavailableSession(hadStoredSession: true);
      }

      throw _authFailureFrom(error);
    }

    if (!_isDriver(user)) {
      await _revokeSilently(storedToken.accessToken);
      await _clearStoredSession();
      return const UnavailableSession(hadStoredSession: true);
    }

    return RestoredSession(user);
  }

  @override
  Future<AuthSession> login({
    required String login,
    required String password,
  }) async {
    late final AuthSession session;

    try {
      session = await remoteDataSource.login(
        LoginRequest(
          login: login.trim(),
          password: password,
          deviceName: deviceName,
        ),
      );
    } on ApiException catch (error) {
      throw _authFailureFrom(error);
    }

    if (!_isDriver(session.user)) {
      await _revokeSilently(session.accessToken);
      throw AuthFailure(
        message: 'PelekaPro is available only to driver accounts.',
        statusCode: 403,
      );
    }

    try {
      await tokenStorage.save(
        StoredAuthToken(
          accessToken: session.accessToken,
          tokenType: session.tokenType,
          expiresAt: session.expiresAt,
        ),
      );
    } on Object {
      await _revokeSilently(session.accessToken);
      throw AuthFailure(
        message:
            'Login succeeded, but the secure session could not be saved. '
            'Please try again.',
      );
    }

    return session;
  }

  @override
  Future<void> logout() async {
    late final StoredAuthToken? storedToken;

    try {
      storedToken = await tokenStorage.read();
    } on Object {
      throw AuthFailure(
        message:
            'The secure session could not be read. Restart the app and try again.',
      );
    }

    if (storedToken == null) {
      return;
    }

    try {
      await remoteDataSource.logout(storedToken.accessToken);
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        throw _authFailureFrom(error);
      }
    }

    await _clearStoredSession();
  }

  bool _isDriver(AuthUser user) {
    return user.role.toLowerCase() == 'driver' && user.driverProfile != null;
  }

  AuthFailure _authFailureFrom(ApiException error) {
    return AuthFailure(
      message: error.message,
      statusCode: error.statusCode,
      fieldErrors: error.fieldErrors,
    );
  }

  Future<void> _clearStoredSession() async {
    try {
      await tokenStorage.clear();
    } on Object {
      throw AuthFailure(
        message:
            'The session could not be removed securely. '
            'Restart the app and try again.',
      );
    }
  }

  Future<void> _revokeSilently(String accessToken) async {
    try {
      await remoteDataSource.logout(accessToken);
    } on Object {
      // The original login failure remains the actionable result for the user.
    }
  }

  @override
  void close() {
    remoteDataSource.close();
  }
}
