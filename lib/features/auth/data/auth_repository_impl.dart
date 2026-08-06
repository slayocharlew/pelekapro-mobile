import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/core/storage/token_storage.dart';
import 'package:pelekapro_mobile/features/auth/data/auth_remote_data_source.dart';
import 'package:pelekapro_mobile/features/auth/data/models/login_request.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_failure.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_session.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.tokenStorage,
    required this.deviceName,
  });

  final AuthRemoteDataSource remoteDataSource;
  final TokenStorage tokenStorage;
  final String deviceName;

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
      throw AuthFailure(
        message: error.message,
        statusCode: error.statusCode,
        fieldErrors: error.fieldErrors,
      );
    }

    if (session.user.role.toLowerCase() != 'driver') {
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
