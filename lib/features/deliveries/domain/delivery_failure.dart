class DeliveryFailure implements Exception {
  const DeliveryFailure({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'DeliveryFailure($statusCode): $message';
}
