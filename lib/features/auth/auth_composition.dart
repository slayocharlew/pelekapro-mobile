import 'package:pelekapro_mobile/core/config/app_config.dart';
import 'package:pelekapro_mobile/core/network/api_client.dart';
import 'package:pelekapro_mobile/core/storage/secure_token_storage.dart';
import 'package:pelekapro_mobile/features/auth/data/auth_remote_data_source.dart';
import 'package:pelekapro_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_failure.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_session.dart';

abstract final class AuthComposition {
  static AuthRepository createRepository() {
    final baseUri = AppConfig.apiBaseUri;

    if (baseUri == null) {
      return const _UnconfiguredAuthRepository();
    }

    final apiClient = ApiClient(baseUri: baseUri);

    return AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSource(apiClient),
      tokenStorage: SecureTokenStorage(),
      deviceName: 'PelekaPro Android',
    );
  }
}

class _UnconfiguredAuthRepository implements AuthRepository {
  const _UnconfiguredAuthRepository();

  @override
  Future<AuthSession> login({required String login, required String password}) {
    throw AuthFailure(
      message:
          'The API connection is not configured. Start the app with '
          'API_BASE_URL set for your PelekaPro server.',
    );
  }

  @override
  void close() {}
}
