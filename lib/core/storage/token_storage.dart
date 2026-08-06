class StoredAuthToken {
  const StoredAuthToken({
    required this.accessToken,
    required this.tokenType,
    this.expiresAt,
  });

  final String accessToken;
  final String tokenType;
  final DateTime? expiresAt;
}

abstract interface class TokenStorage {
  Future<void> save(StoredAuthToken token);

  Future<StoredAuthToken?> read();

  Future<void> clear();
}
