import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pelekapro_mobile/core/network/api_client.dart';
import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/features/deliveries/data/delivery_remote_data_source.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';

void main() {
  group('DeliveryRemoteDataSource', () {
    test('gets and parses the documented assigned-delivery response', () async {
      late http.Request capturedRequest;
      final httpClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode(_assignedDeliveriesResponse), 200);
      });
      final dataSource = DeliveryRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: httpClient,
        ),
      );

      final deliveries = await dataSource.fetchAssignedDeliveries(
        'stored-driver-token',
      );

      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.path, '/api/driver/deliveries');
      expect(
        capturedRequest.headers['authorization'],
        'Bearer stored-driver-token',
      );
      expect(deliveries, hasLength(1));
      final delivery = deliveries.single;
      expect(delivery.id, 101);
      expect(delivery.deliveryNumber, 'PP-24031');
      expect(delivery.status, DeliveryStatus.assigned);
      expect(delivery.pickup.latitude, -6.7924);
      expect(delivery.customer.name, 'Asha Juma');
      expect(delivery.customerAddress?.ward, 'Mikocheni');
      expect(delivery.items.single.amount, 25000);
      expect(delivery.payment.amountToCollect, 25000);
      expect(delivery.payment.record?.status, 'pending');
      expect(delivery.requirements.pinRequired, isTrue);
      expect(
        delivery.timestamps.assignedAt,
        DateTime.parse('2026-08-17T07:00:00.000000Z'),
      );
    });

    test('accepts an empty assigned-delivery list', () async {
      final httpClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Assigned deliveries retrieved successfully',
            'data': <Object?>[],
          }),
          200,
        );
      });
      final dataSource = DeliveryRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: httpClient,
        ),
      );

      expect(
        await dataSource.fetchAssignedDeliveries('stored-driver-token'),
        isEmpty,
      );
    });

    test('gets delivery details and active failure reasons', () async {
      late http.Request capturedRequest;
      final payload = jsonDecode(jsonEncode(_assignedDeliveriesResponse));
      final delivery =
          (payload['data'] as List<Object?>).single as Map<String, dynamic>;
      delivery['failure_reasons'] = [
        {'id': 7, 'name': 'Customer not reachable'},
        {'id': 9, 'name': 'Wrong address'},
      ];
      final dataSource = DeliveryRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({
                'success': true,
                'message': 'Assigned delivery retrieved successfully',
                'data': delivery,
              }),
              200,
            );
          }),
        ),
      );

      final details = await dataSource.fetchDeliveryDetails(
        101,
        'stored-driver-token',
      );

      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.path, '/api/driver/deliveries/101');
      expect(
        capturedRequest.headers['authorization'],
        'Bearer stored-driver-token',
      );
      expect(details.delivery.deliveryNumber, 'PP-24031');
      expect(details.failureReasons, hasLength(2));
      expect(details.failureReasons.first.id, 7);
      expect(details.failureReasons.first.name, 'Customer not reachable');
    });

    test('rejects detail responses without valid failure reasons', () async {
      final payload = jsonDecode(jsonEncode(_assignedDeliveriesResponse));
      final delivery =
          (payload['data'] as List<Object?>).single as Map<String, dynamic>;
      final dataSource = DeliveryRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'success': true, 'data': delivery}),
              200,
            ),
          ),
        ),
      );

      await expectLater(
        dataSource.fetchDeliveryDetails(101, 'token'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('invalid response'),
          ),
        ),
      );

      delivery['failure_reasons'] = <Object?>[];
      delivery['id'] = 999;
      await expectLater(
        dataSource.fetchDeliveryDetails(101, 'token'),
        throwsA(isA<ApiException>()),
      );
    });

    test('accepts nullable delivery contact and address fields', () async {
      final payload = jsonDecode(jsonEncode(_assignedDeliveriesResponse));
      final delivery =
          (payload['data'] as List<Object?>).single as Map<String, dynamic>;
      final pickup = delivery['pickup'] as Map<String, dynamic>;
      pickup
        ..['name'] = null
        ..['phone'] = null
        ..['address'] = null
        ..['latitude'] = null
        ..['longitude'] = null;
      delivery['customer_address'] = null;

      final dataSource = DeliveryRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: MockClient(
            (_) async => http.Response(jsonEncode(payload), 200),
          ),
        ),
      );

      final parsed = await dataSource.fetchAssignedDeliveries('token');

      expect(parsed.single.pickup.name, isNull);
      expect(parsed.single.pickup.address, isNull);
      expect(parsed.single.customerAddress, isNull);
    });

    test('rejects malformed success envelopes and delivery values', () async {
      final missingData = DeliveryRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: MockClient(
            (_) async => http.Response(jsonEncode({'success': true}), 200),
          ),
        ),
      );

      await expectLater(
        missingData.fetchAssignedDeliveries('token'),
        throwsA(isA<ApiException>()),
      );

      final malformed = Map<String, Object?>.from(_assignedDeliveriesResponse);
      final data = List<Object?>.from(malformed['data']! as List<Object?>);
      final delivery = Map<String, Object?>.from(
        data.single! as Map<String, Object?>,
      );
      delivery['status'] = 'invented_status';
      malformed['data'] = [delivery];
      final invalidStatus = DeliveryRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: MockClient(
            (_) async => http.Response(jsonEncode(malformed), 200),
          ),
        ),
      );

      await expectLater(
        invalidStatus.fetchAssignedDeliveries('token'),
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

const _assignedDeliveriesResponse = {
  'success': true,
  'message': 'Assigned deliveries retrieved successfully',
  'data': [
    {
      'id': 101,
      'delivery_number': 'PP-24031',
      'tracking_code': 'TRACK-24031',
      'status': 'assigned',
      'pickup': {
        'name': 'PelekaPro pickup',
        'phone': '+255 700 000 001',
        'address': 'Uhuru Street, Kariakoo, Dar es Salaam',
        'latitude': '-6.7924000',
        'longitude': '39.2083000',
      },
      'dropoff': {
        'name': 'Asha Juma',
        'phone': '+255 712 345 678',
        'address': 'Mwai Kibaki Road, Mikocheni, Dar es Salaam',
        'latitude': '-6.7690000',
        'longitude': '39.2340000',
      },
      'customer': {'id': 15, 'name': 'Asha Juma', 'phone': '+255 712 345 678'},
      'customer_address': {
        'label': 'Home',
        'region': 'Dar es Salaam',
        'district': 'Kinondoni',
        'ward': 'Mikocheni',
        'street': 'Mwai Kibaki Road',
        'landmark': null,
        'building_instruction': 'Call on arrival',
        'latitude': '-6.7690000',
        'longitude': '39.2340000',
      },
      'items': [
        {
          'id': 1,
          'delivery_id': 101,
          'item_name': 'Documents',
          'quantity': 1,
          'amount': '25000.00',
          'description': null,
          'created_at': '2026-08-17T07:00:00.000000Z',
          'updated_at': '2026-08-17T07:00:00.000000Z',
        },
      ],
      'payment': {
        'method': 'cash_on_delivery',
        'amount_to_collect': '25000.00',
        'delivery_fee': '3000.00',
        'payment_record': {
          'payment_method': 'cash',
          'expected_amount': '25000.00',
          'collected_amount': '0.00',
          'payment_status': 'pending',
        },
      },
      'requirements': {
        'pin_required': true,
        'proof_supported': true,
        'available_proof_types': ['photo', 'signature'],
      },
      'timestamps': {
        'assigned_at': '2026-08-17T07:00:00.000000Z',
        'started_at': null,
        'arrived_at': null,
        'delivered_at': null,
        'failed_at': null,
        'cancelled_at': null,
      },
    },
  ],
};
