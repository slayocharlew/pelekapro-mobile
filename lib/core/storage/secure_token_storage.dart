import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pelekapro_mobile/core/storage/token_storage.dart';

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'pelekapro.auth.token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> save(StoredAuthToken token) {
    final value = jsonEncode({
      'access_token': token.accessToken,
      'token_type': token.tokenType,
      'expires_at': token.expiresAt?.toIso8601String(),
    });

    return _storage.write(key: _tokenKey, value: value);
  }

  @override
  Future<StoredAuthToken?> read() async {
    final value = await _storage.read(key: _tokenKey);

    if (value == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid stored token.');
      }

      final accessToken = decoded['access_token'];
      final tokenType = decoded['token_type'];
      final expiresAtValue = decoded['expires_at'];

      if (accessToken is! String ||
          accessToken.isEmpty ||
          tokenType is! String ||
          tokenType.isEmpty) {
        throw const FormatException('Invalid stored token.');
      }

      final expiresAt = expiresAtValue is String
          ? DateTime.tryParse(expiresAtValue)
          : null;

      if (expiresAtValue != null && expiresAt == null) {
        throw const FormatException('Invalid stored token expiry.');
      }

      return StoredAuthToken(
        accessToken: accessToken,
        tokenType: tokenType,
        expiresAt: expiresAt,
      );
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _tokenKey);
  }
}
