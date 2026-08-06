class AuthFailure implements Exception {
  AuthFailure({
    required this.message,
    this.statusCode,
    Map<String, List<String>> fieldErrors = const {},
  }) : fieldErrors = Map<String, List<String>>.unmodifiable({
         for (final entry in fieldErrors.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       });

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  String? firstErrorFor(String field) {
    final messages = fieldErrors[field];
    return messages == null || messages.isEmpty ? null : messages.first;
  }

  @override
  String toString() => 'AuthFailure($statusCode): $message';
}
