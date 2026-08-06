import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pelekapro_mobile/core/network/api_client.dart';
import 'package:pelekapro_mobile/core/network/api_exception.dart';

void main() {
  group('ApiClient', () {
    test('posts JSON with the required API headers', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'accepted': true},
          }),
          200,
        );
      });
      final apiClient = ApiClient(
        baseUri: Uri.parse('http://10.0.2.2:8000'),
        client: client,
      );

      final response = await apiClient.postJson(
        '/api/auth/login',
        body: const {
          'login': '+255700000000',
          'password': 'safe-test-password',
          'device_name': 'PelekaPro Android',
        },
      );

      expect(
        capturedRequest.url,
        Uri.parse('http://10.0.2.2:8000/api/auth/login'),
      );
      expect(capturedRequest.headers['accept'], 'application/json');
      expect(capturedRequest.headers['content-type'], 'application/json');
      expect(jsonDecode(capturedRequest.body), {
        'login': '+255700000000',
        'password': 'safe-test-password',
        'device_name': 'PelekaPro Android',
      });
      expect(response['success'], isTrue);
    });

    test('sends the bearer token on authenticated requests', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'success': true}), 200);
      });
      final apiClient = ApiClient(
        baseUri: Uri.parse('https://api.pelekapro.example'),
        client: client,
      );

      await apiClient.postJson('/api/auth/logout', bearerToken: 'test-token');

      expect(capturedRequest.headers['authorization'], 'Bearer test-token');
    });

    test('maps validation responses to field errors', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Validation failed',
            'errors': {
              'login': ['The login field is required.'],
            },
          }),
          422,
        );
      });
      final apiClient = ApiClient(
        baseUri: Uri.parse('https://api.pelekapro.example'),
        client: client,
      );

      await expectLater(
        apiClient.postJson('/api/auth/login', body: const {}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having((error) => error.message, 'message', 'Validation failed')
              .having((error) => error.fieldErrors['login'], 'login errors', [
                'The login field is required.',
              ]),
        ),
      );
    });

    test('rejects malformed successful responses', () async {
      final client = MockClient((_) async => http.Response('<html>', 200));
      final apiClient = ApiClient(
        baseUri: Uri.parse('https://api.pelekapro.example'),
        client: client,
      );

      await expectLater(
        apiClient.postJson('/api/auth/login'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('invalid response'),
          ),
        ),
      );
    });
  });
}
