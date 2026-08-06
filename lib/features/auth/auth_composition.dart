import 'package:pelekapro_mobile/core/config/app_config.dart';
import 'package:pelekapro_mobile/core/network/api_client.dart';
import 'package:pelekapro_mobile/core/storage/secure_token_storage.dart';
import 'package:pelekapro_mobile/features/auth/data/auth_remote_data_source.dart';
import 'package:pelekapro_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_failure.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_session.dart';
import 'package:pelekapro_mobile/features/auth/domain/session_restore_result.dart';

abstract final class AuthComposition {
  static AuthRepository createRepository() {
    final baseUri = AppConfig.apiBaseUri;
    final tokenStorage = SecureTokenStorage();

    if (baseUri == null) {
      return _UnconfiguredAuthRepository(tokenStorage);
    }

    final apiClient = ApiClient(baseUri: baseUri);

    return AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSource(apiClient),
      tokenStorage: tokenStorage,
      deviceName: 'PelekaPro Android',
      now: DateTime.now,
    );
  }
}

class _UnconfiguredAuthRepository implements AuthRepository {
  const _UnconfiguredAuthRepository(this._tokenStorage);

  final SecureTokenStorage _tokenStorage;

  @override
  Future<SessionRestoreResult> restoreSession() async {
    try {
      final storedToken = await _tokenStorage.read();

      if (storedToken == null) {
        return const UnavailableSession(hadStoredSession: false);
      }
    } on Object {
      throw AuthFailure(
        message:
            'The secure session could not be read. Restart the app and try again.',
      );
    }

    throw AuthFailure(message: _configurationMessage);
  }

  @override
  Future<AuthSession> login({required String login, required String password}) {
    throw AuthFailure(message: _configurationMessage);
  }

  @override
  void close() {}
}

const _configurationMessage =
    'The API connection is not configured. Start the app with '
    'API_BASE_URL set for your PelekaPro server.';
