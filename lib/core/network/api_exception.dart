class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    Map<String, List<String>> fieldErrors = const {},
  }) : fieldErrors = Map<String, List<String>>.unmodifiable({
         for (final entry in fieldErrors.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       });

  factory ApiException.fromPayload({
    required Object? payload,
    int? statusCode,
    String? fallbackMessage,
  }) {
    final json = payload is Map<String, dynamic> ? payload : null;
    final serverMessage = json?['message'];
    final message = serverMessage is String && serverMessage.trim().isNotEmpty
        ? serverMessage.trim()
        : fallbackMessage ?? _fallbackMessageFor(statusCode);

    return ApiException(
      message: message,
      statusCode: statusCode,
      fieldErrors: _parseFieldErrors(json?['errors']),
    );
  }

  factory ApiException.invalidResponse({int? statusCode}) {
    return ApiException(
      message: 'PelekaPro returned an invalid response. Please try again.',
      statusCode: statusCode,
    );
  }

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  static Map<String, List<String>> _parseFieldErrors(Object? errors) {
    if (errors is! Map<String, dynamic>) {
      return const {};
    }

    final parsed = <String, List<String>>{};

    for (final entry in errors.entries) {
      final value = entry.value;
      final messages = switch (value) {
        String message when message.trim().isNotEmpty => [message.trim()],
        List<Object?> values =>
          values
              .whereType<String>()
              .map((message) => message.trim())
              .where((message) => message.isNotEmpty)
              .toList(growable: false),
        _ => const <String>[],
      };

      if (messages.isNotEmpty) {
        parsed[entry.key] = messages;
      }
    }

    return parsed;
  }

  static String _fallbackMessageFor(int? statusCode) {
    return switch (statusCode) {
      401 => 'The phone number, email, or password is incorrect.',
      403 => 'This account is not allowed to perform that action.',
      404 => 'The requested PelekaPro service was not found.',
      409 => 'The request conflicts with the current server state.',
      422 => 'Check the highlighted information and try again.',
      429 => 'Too many attempts. Please wait before trying again.',
      final code when code != null && code >= 500 =>
        'PelekaPro is temporarily unavailable. Please try again.',
      _ => 'The request could not be completed. Please try again.',
    };
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
