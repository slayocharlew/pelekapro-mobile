const String apiBaseUrlEnvironment = String.fromEnvironment('API_BASE_URL');
const String routingBaseUrlEnvironment = String.fromEnvironment(
  'ROUTING_BASE_URL',
);
const String mapTileUrlEnvironment = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

abstract final class AppConfig {
  static final Uri? apiBaseUri = _parseApiBaseUrl(apiBaseUrlEnvironment);
  static final Uri? routingBaseUri = _parseApiBaseUrl(
    routingBaseUrlEnvironment,
  );
  static final String? mapTileUrlTemplate = _parseMapTileUrl(
    mapTileUrlEnvironment,
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

  static String? _parseMapTileUrl(String value) {
    final candidate = value.trim();
    if (!candidate.contains('{z}') ||
        !candidate.contains('{x}') ||
        !candidate.contains('{y}')) {
      return null;
    }

    final uri = Uri.tryParse(
      candidate
          .replaceAll('{z}', '0')
          .replaceAll('{x}', '0')
          .replaceAll('{y}', '0'),
    );
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return candidate;
  }
}
