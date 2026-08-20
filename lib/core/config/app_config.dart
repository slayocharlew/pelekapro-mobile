const String apiBaseUrlEnvironment = String.fromEnvironment('API_BASE_URL');
const String routingBaseUrlEnvironment = String.fromEnvironment(
  'ROUTING_BASE_URL',
);

abstract final class AppConfig {
  static final Uri? apiBaseUri = _parseApiBaseUrl(apiBaseUrlEnvironment);
  static final Uri? routingBaseUri = _parseApiBaseUrl(
    routingBaseUrlEnvironment,
  );

  static bool get isApiBaseUrlConfigured => apiBaseUri != null;

  static String get apiBaseUrl => apiBaseUri?.toString() ?? '';

  static String get apiHostLabel => apiBaseUri?.authority ?? 'Not configured';

  static Uri? _parseApiBaseUrl(String value) {
    final candidate = value.trim();

    if (candidate.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(candidate);

    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }

    final normalizedPath = uri.path == '/'
        ? ''
        : uri.path.replaceFirst(RegExp(r'/+$'), '');

    return uri.replace(path: normalizedPath);
  }
}
