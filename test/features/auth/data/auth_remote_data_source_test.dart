import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pelekapro_mobile/core/network/api_client.dart';
import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/features/auth/data/auth_remote_data_source.dart';
import 'package:pelekapro_mobile/features/auth/data/models/login_request.dart';

void main() {
  group('AuthRemoteDataSource', () {
    test('parses the documented login response', () async {
      final httpClient = MockClient((_) async {
        return http.Response(jsonEncode(_loginResponse), 200);
      });
      final dataSource = AuthRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: httpClient,
        ),
      );

      final session = await dataSource.login(
        const LoginRequest(
          login: '+255700000000',
          password: 'safe-test-password',
          deviceName: 'PelekaPro Android',
        ),
      );

      expect(session.accessToken, 'server-token');
      expect(session.tokenType, 'Bearer');
      expect(session.expiresAt, DateTime.parse('2026-09-05T10:30:00Z'));
      expect(session.user.name, 'Driver Name');
      expect(session.user.role, 'driver');
      expect(session.user.driverProfile?.isAvailable, isTrue);
    });

    test('rejects a success envelope without session data', () async {
      final httpClient = MockClient((_) async {
        return http.Response(jsonEncode({'success': true}), 200);
      });
      final dataSource = AuthRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: httpClient,
        ),
      );

      await expectLater(
        dataSource.login(
          const LoginRequest(
            login: '+255700000000',
            password: 'safe-test-password',
            deviceName: 'PelekaPro Android',
          ),
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });
}

const _loginResponse = {
  'success': true,
  'message': 'Login successful',
  'data': {
    'access_token': 'server-token',
    'token_type': 'Bearer',
    'expires_at': '2026-09-05T10:30:00Z',
    'user': {
      'id': 42,
      'business_id': 7,
      'branch_id': 3,
      'name': 'Driver Name',
      'phone': '+255700000000',
      'email': 'driver@example.com',
      'status': 'active',
      'role': 'driver',
      'driver_profile': {
        'id': 9,
        'is_available': true,
        'current_status': 'available',
      },
    },
  },
};
