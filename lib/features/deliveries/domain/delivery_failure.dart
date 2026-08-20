class DeliveryFailure implements Exception {
  const DeliveryFailure({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => statusCode == 401;

  String? fieldError(String field) {
    final errors = fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.first;
  }

  @override
  String toString() => 'DeliveryFailure($statusCode): $message';
}
