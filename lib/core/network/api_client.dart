import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/core/network/multipart_file_data.dart';

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

  Future<JsonObject> getJson(String endpoint, {String? bearerToken}) {
    final headers = _headers(bearerToken: bearerToken);

    return _sendJson(() => _client.get(_resolve(endpoint), headers: headers));
  }

  Future<JsonObject> postJson(
    String endpoint, {
    JsonObject? body,
    String? bearerToken,
  }) {
    final headers = _headers(bearerToken: bearerToken);

    return _sendJson(
      () => _client.post(
        _resolve(endpoint),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<JsonObject> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    required MultipartFileData file,
    String? bearerToken,
  }) {
    final request = http.MultipartRequest('POST', _resolve(endpoint))
      ..headers.addAll(
        _headers(bearerToken: bearerToken, includeContentType: false),
      )
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          file.fieldName,
          file.bytes,
          filename: file.fileName,
        ),
      );

    return _sendJson(() async {
      final streamedResponse = await _client.send(request);
      return http.Response.fromStream(streamedResponse);
    });
  }

  Map<String, String> _headers({
    String? bearerToken,
    bool includeContentType = true,
  }) {
    return {
      HttpHeaders.acceptHeader: 'application/json',
      if (includeContentType) HttpHeaders.contentTypeHeader: 'application/json',
      if (bearerToken != null)
        HttpHeaders.authorizationHeader: 'Bearer $bearerToken',
    };
  }

  Future<JsonObject> _sendJson(Future<http.Response> Function() request) async {
    late final http.Response response;

    try {
      response = await request().timeout(requestTimeout);
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
