import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pelekapro_mobile/core/network/api_exception.dart';

typedef JsonObject = Map<String, dynamic>;

class ApiClient {
  ApiClient({
    required this.baseUri,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       assert(requestTimeout > Duration.zero);

  final Uri baseUri;
  final Duration requestTimeout;
  final http.Client _client;
  final bool _ownsClient;

  Future<JsonObject> postJson(
    String endpoint, {
    JsonObject? body,
    String? bearerToken,
  }) async {
    final headers = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
      if (bearerToken != null)
        HttpHeaders.authorizationHeader: 'Bearer $bearerToken',
    };

    late final http.Response response;

    try {
      response = await _client
          .post(
            _resolve(endpoint),
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw ApiException(
        message: 'The request timed out. Check your connection and try again.',
      );
    } on IOException {
      throw ApiException(
        message:
            'Unable to reach PelekaPro. Check your connection and try again.',
      );
    } on http.ClientException {
      throw ApiException(
        message:
            'Unable to reach PelekaPro. Check your connection and try again.',
      );
    }

    final isSuccessful =
        response.statusCode >= 200 && response.statusCode < 300;
    final payload = _decodeResponse(response, isSuccessful: isSuccessful);

    if (!isSuccessful) {
      throw ApiException.fromPayload(
        payload: payload,
        statusCode: response.statusCode,
      );
    }

    return payload ?? const {};
  }

  Uri _resolve(String endpoint) {
    final endpointPath = endpoint.replaceFirst(RegExp(r'^/+'), '');
    final basePath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final path = basePath.isEmpty
        ? '/$endpointPath'
        : '$basePath/$endpointPath';

    return baseUri.replace(path: path, query: null, fragment: null);
  }

  JsonObject? _decodeResponse(
    http.Response response, {
    required bool isSuccessful,
  }) {
    if (response.body.trim().isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      if (!isSuccessful) {
        return null;
      }

      throw ApiException.invalidResponse(statusCode: response.statusCode);
    }

    if (isSuccessful) {
      throw ApiException.invalidResponse(statusCode: response.statusCode);
    }

    return null;
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
