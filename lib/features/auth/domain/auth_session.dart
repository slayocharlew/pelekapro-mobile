import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.user,
    this.expiresAt,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'];
    final tokenType = json['token_type'];
    final expiresAtValue = json['expires_at'];
    final userJson = json['user'];

    if (accessToken is! String ||
        accessToken.isEmpty ||
        tokenType is! String ||
        tokenType.isEmpty ||
        (expiresAtValue != null && expiresAtValue is! String) ||
        userJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid authentication session.');
    }

    final expiresAt = expiresAtValue == null
        ? null
        : DateTime.tryParse(expiresAtValue as String);

    if (expiresAtValue != null && expiresAt == null) {
      throw const FormatException('Invalid authentication expiry.');
    }

    return AuthSession(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresAt: expiresAt,
      user: AuthUser.fromJson(userJson),
    );
  }

  final String accessToken;
  final String tokenType;
  final DateTime? expiresAt;
  final AuthUser user;
}
