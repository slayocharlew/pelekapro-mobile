class FirebaseTrackingCredential {
  const FirebaseTrackingCredential({
    required this.token,
    required this.deliveryAlias,
    required this.sessionAlias,
    required this.databasePath,
    required this.expiresAt,
  });

  final String token;
  final String deliveryAlias;
  final String sessionAlias;
  final String databasePath;
  final DateTime expiresAt;

  bool needsRefresh(DateTime now) =>
      !expiresAt.toUtc().isAfter(now.toUtc().add(const Duration(minutes: 5)));

  factory FirebaseTrackingCredential.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final deliveryAlias = json['delivery_alias'];
    final sessionAlias = json['session_alias'];
    final databasePath = json['database_path'];
    final expiresAt = json['expires_at'];

    if (token is! String ||
        token.isEmpty ||
        deliveryAlias is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(deliveryAlias) ||
        sessionAlias is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sessionAlias) ||
        databasePath != 'delivery_tracking/$deliveryAlias' ||
        expiresAt is! int) {
      throw const FormatException('Invalid Firebase tracking credential.');
    }

    return FirebaseTrackingCredential(
      token: token,
      deliveryAlias: deliveryAlias,
      sessionAlias: sessionAlias,
      databasePath: databasePath as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        expiresAt * 1000,
        isUtc: true,
      ),
    );
  }
}
