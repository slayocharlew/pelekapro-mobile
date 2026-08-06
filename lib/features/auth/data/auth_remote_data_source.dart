import 'package:pelekapro_mobile/core/network/api_client.dart';
import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/features/auth/data/models/login_request.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_session.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthSession> login(LoginRequest request) async {
    final response = await _apiClient.postJson(
      '/api/auth/login',
      body: request.toJson(),
    );

    if (response['success'] != true) {
      throw ApiException.fromPayload(payload: response);
    }

    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw ApiException.invalidResponse();
    }

    try {
      return AuthSession.fromJson(data);
    } on FormatException {
      throw ApiException.invalidResponse();
    }
  }

  Future<void> logout(String accessToken) async {
    await _apiClient.postJson('/api/auth/logout', bearerToken: accessToken);
  }

  void close() {
    _apiClient.close();
  }
}
