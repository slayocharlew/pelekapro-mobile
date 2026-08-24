import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pelekapro_mobile/core/network/api_client.dart';
import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/features/deliveries/data/delivery_remote_data_source.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_completion_request.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_proof_photo.dart';
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
      expect(delivery.requirements.proofSupported, isTrue);
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

    test(
      'posts an empty start request and parses the started delivery',
      () async {
        late http.Request capturedRequest;
        final payload = jsonDecode(jsonEncode(_assignedDeliveriesResponse));
        final delivery =
            (payload['data'] as List<Object?>).single as Map<String, dynamic>;
        delivery['status'] = 'on_the_way';
        final timestamps = delivery['timestamps'] as Map<String, dynamic>;
        timestamps['started_at'] = '2026-08-17T08:15:00.000000Z';
        final dataSource = DeliveryRemoteDataSource(
          ApiClient(
            baseUri: Uri.parse('https://api.pelekapro.example'),
            client: MockClient((request) async {
              capturedRequest = request;
              return http.Response(
                jsonEncode({
                  'success': true,
                  'message': 'Delivery started successfully',
                  'data': delivery,
                }),
                200,
              );
            }),
          ),
        );

        final started = await dataSource.startDelivery(
          101,
          'stored-driver-token',
        );

        expect(capturedRequest.method, 'POST');
        expect(capturedRequest.url.path, '/api/driver/deliveries/101/start');
        expect(capturedRequest.body, isEmpty);
        expect(
          capturedRequest.headers['authorization'],
          'Bearer stored-driver-token',
        );
        expect(started.id, 101);
        expect(started.status, DeliveryStatus.onTheWay);
        expect(
          started.timestamps.startedAt,
          DateTime.parse('2026-08-17T08:15:00.000000Z'),
        );
      },
    );

    test('rejects an unexpected start response id or status', () async {
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
        dataSource.startDelivery(101, 'token'),
        throwsA(isA<ApiException>()),
      );

      delivery['status'] = 'on_the_way';
      delivery['id'] = 999;
      await expectLater(
        dataSource.startDelivery(101, 'token'),
        throwsA(isA<ApiException>()),
      );
    });

    test(
      'posts documented completion JSON without server-owned fields',
      () async {
        late http.Request capturedRequest;
        final payload = jsonDecode(jsonEncode(_assignedDeliveriesResponse));
        final delivery =
            (payload['data'] as List<Object?>).single as Map<String, dynamic>;
        delivery['status'] = 'delivered';
        final timestamps = delivery['timestamps'] as Map<String, dynamic>;
        timestamps['started_at'] = '2026-08-17T08:15:00.000000Z';
        timestamps['delivered_at'] = '2026-08-17T08:45:00.000000Z';
        final dataSource = DeliveryRemoteDataSource(
          ApiClient(
            baseUri: Uri.parse('https://api.pelekapro.example'),
            client: MockClient((request) async {
              capturedRequest = request;
              return http.Response(
                jsonEncode({
                  'success': true,
                  'message': 'Delivery completed successfully',
                  'data': delivery,
                }),
                200,
              );
            }),
          ),
        );

        final completed = await dataSource.completeDelivery(
          101,
          const DeliveryCompletionRequest(
            collectedAmount: 25000,
            deliveredLatitude: -6.7924,
            deliveredLongitude: 39.2083,
          ),
          'stored-driver-token',
        );

        expect(capturedRequest.method, 'POST');
        expect(capturedRequest.url.path, '/api/driver/deliveries/101/deliver');
        expect(capturedRequest.headers['content-type'], 'application/json');
        expect(
          capturedRequest.headers['authorization'],
          'Bearer stored-driver-token',
        );
        expect(jsonDecode(capturedRequest.body), {
          'collected_amount': 25000.0,
          'delivered_latitude': -6.7924,
          'delivered_longitude': 39.2083,
        });
        expect(capturedRequest.body, isNot(contains('expected_amount')));
        expect(capturedRequest.body, isNot(contains('payment_method')));
        expect(capturedRequest.body, isNot(contains('delivery_id')));
        expect(completed.id, 101);
        expect(completed.status, DeliveryStatus.delivered);
      },
    );

    test('posts optional proof photo as documented multipart data', () async {
      late http.Request capturedRequest;
      final payload = jsonDecode(jsonEncode(_assignedDeliveriesResponse));
      final delivery =
          (payload['data'] as List<Object?>).single as Map<String, dynamic>;
      delivery['status'] = 'delivered';
      final timestamps = delivery['timestamps'] as Map<String, dynamic>;
      timestamps['started_at'] = '2026-08-17T08:15:00.000000Z';
      timestamps['delivered_at'] = '2026-08-17T08:45:00.000000Z';
      final dataSource = DeliveryRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({'success': true, 'data': delivery}),
              200,
            );
          }),
        ),
      );

      final completed = await dataSource.completeDelivery(
        101,
        DeliveryCompletionRequest(
          collectedAmount: 25000,
          proofPhoto: DeliveryProofPhoto(
            fileName: 'proof.jpg',
            mimeType: 'image/jpeg',
            bytes: const [0xFF, 0xD8, 0xFF, 0xD9],
          ),
        ),
        'stored-driver-token',
      );

      final contentType = capturedRequest.headers['content-type'];
      final multipartBody = latin1.decode(capturedRequest.bodyBytes);
      expect(contentType, startsWith('multipart/form-data; boundary='));
      expect(multipartBody, isNot(contains('name="delivery_pin"')));
      expect(multipartBody, contains('name="collected_amount"'));
      expect(multipartBody, contains('25000.0'));
      expect(multipartBody, contains('name="proof_type"'));
      expect(multipartBody, contains('photo'));
      expect(multipartBody, contains('name="proof_file"'));
      expect(multipartBody, contains('filename="proof.jpg"'));
      expect(multipartBody, isNot(contains('expected_amount')));
      expect(multipartBody, isNot(contains('payment_method')));
      expect(completed.status, DeliveryStatus.delivered);
    });

    test('rejects a completion response that is not delivered', () async {
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
        dataSource.completeDelivery(
          101,
          const DeliveryCompletionRequest(),
          'token',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('posts only the documented GPS fields and parses 201', () async {
      late http.Request capturedRequest;
      final dataSource = DeliveryRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({
                'success': true,
                'message': 'Location recorded successfully',
                'data': {
                  'latitude': '-6.7924000',
                  'longitude': '39.2083000',
                  'accuracy': '8.50',
                  'speed': '6.20',
                  'heading': '135.00',
                  'battery_level': null,
                  'recorded_at': '2026-08-17T08:15:30.000000Z',
                },
              }),
              201,
            );
          }),
        ),
      );
      final sample = DeliveryLocationSample(
        latitude: -6.7924,
        longitude: 39.2083,
        accuracy: 8.5,
        speed: 6.2,
        heading: 135,
        recordedAt: DateTime.utc(2026, 8, 17, 8, 15, 30),
      );

      final recorded = await dataSource.submitLocation(
        101,
        sample,
        'stored-driver-token',
      );

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/driver/deliveries/101/locations');
      expect(
        capturedRequest.headers['authorization'],
        'Bearer stored-driver-token',
      );
      expect(jsonDecode(capturedRequest.body), {
        'latitude': -6.7924,
        'longitude': 39.2083,
        'accuracy': 8.5,
        'speed': 6.2,
        'heading': 135.0,
        'recorded_at': '2026-08-17T08:15:30.000Z',
      });
      expect(capturedRequest.body, isNot(contains('delivery_id')));
      expect(capturedRequest.body, isNot(contains('driver_id')));
      expect(capturedRequest.body, isNot(contains('tracking_session_id')));
      expect(capturedRequest.body, isNot(contains('battery_level')));
      expect(recorded.latitude, -6.7924);
      expect(recorded.heading, 135);
      expect(recorded.batteryLevel, isNull);
      expect(recorded.recordedAt, DateTime.utc(2026, 8, 17, 8, 15, 30));
    });

    test(
      'requests and validates a scoped Firebase tracking credential',
      () async {
        late http.Request capturedRequest;
        const deliveryAlias =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const sessionAlias =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final dataSource = DeliveryRemoteDataSource(
          ApiClient(
            baseUri: Uri.parse('https://api.pelekapro.example'),
            client: MockClient((request) async {
              capturedRequest = request;
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'token': 'short-lived-custom-token',
                    'delivery_alias': deliveryAlias,
                    'session_alias': sessionAlias,
                    'database_path': 'delivery_tracking/$deliveryAlias',
                    'expires_at': 1787567400,
                  },
                }),
                200,
              );
            }),
          ),
        );

        final credential = await dataSource.fetchTrackingCredential(
          101,
          'stored-driver-token',
        );

        expect(capturedRequest.method, 'POST');
        expect(
          capturedRequest.url.path,
          '/api/driver/deliveries/101/tracking-credentials',
        );
        expect(
          capturedRequest.headers['authorization'],
          'Bearer stored-driver-token',
        );
        expect(credential.token, 'short-lived-custom-token');
        expect(credential.deliveryAlias, deliveryAlias);
        expect(credential.sessionAlias, sessionAlias);
      },
    );

    test('accepts the documented duplicate-location 200 response', () async {
      final dataSource = DeliveryRemoteDataSource(
        ApiClient(
          baseUri: Uri.parse('https://api.pelekapro.example'),
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'success': true,
                'message': 'Location already recorded',
                'data': {
                  'latitude': '-6.7924000',
                  'longitude': '39.2083000',
                  'accuracy': null,
                  'speed': null,
                  'heading': null,
                  'battery_level': null,
                  'recorded_at': '2026-08-17T08:15:30.000000Z',
                },
              }),
              200,
            ),
          ),
        ),
      );

      final recorded = await dataSource.submitLocation(
        101,
        DeliveryLocationSample(
          latitude: -6.7924,
          longitude: 39.2083,
          recordedAt: DateTime.utc(2026, 8, 17, 8, 15, 30),
        ),
        'token',
      );

      expect(recorded.speed, isNull);
      expect(recorded.heading, isNull);
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
