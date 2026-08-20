import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/core/storage/token_storage.dart';
import 'package:pelekapro_mobile/features/deliveries/data/delivery_remote_data_source.dart';
import 'package:pelekapro_mobile/features/deliveries/data/delivery_repository_impl.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_completion_request.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';

import '../../../helpers/driver_delivery_fixture.dart';

void main() {
  group('DeliveryRepositoryImpl', () {
    test('uses the token in secure storage for the assigned list', () async {
      final remote = _FakeDeliveryRemoteDataSource(
        deliveries: assignedDeliveriesFixture(),
      );
      final storage = _MemoryTokenStorage(
        token: const StoredAuthToken(
          accessToken: 'stored-token',
          tokenType: 'Bearer',
        ),
      );
      final repository = DeliveryRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        now: _now,
      );

      final deliveries = await repository.fetchAssignedDeliveries();

      expect(deliveries, hasLength(4));
      expect(remote.accessToken, 'stored-token');
      expect(storage.clearCount, 0);
    });

    test(
      'uses the secure token and selected id for delivery details',
      () async {
        final remote = _FakeDeliveryRemoteDataSource(
          details: driverDeliveryDetailsFixture(),
        );
        final storage = _MemoryTokenStorage(
          token: const StoredAuthToken(
            accessToken: 'stored-detail-token',
            tokenType: 'Bearer',
          ),
        );
        final repository = DeliveryRepositoryImpl(
          remoteDataSource: remote,
          tokenStorage: storage,
          now: _now,
        );

        final details = await repository.fetchDeliveryDetails(101);

        expect(details.delivery.id, 101);
        expect(details.failureReasons, hasLength(5));
        expect(remote.detailAccessToken, 'stored-detail-token');
        expect(remote.deliveryId, 101);
        expect(remote.detailCalls, 1);
        expect(storage.clearCount, 0);
      },
    );

    test('uses the secure token and selected id to start delivery', () async {
      final remote = _FakeDeliveryRemoteDataSource(
        startedDelivery: driverDeliveryFixture(status: DeliveryStatus.onTheWay),
      );
      final storage = _MemoryTokenStorage(
        token: const StoredAuthToken(
          accessToken: 'stored-start-token',
          tokenType: 'Bearer',
        ),
      );
      final repository = DeliveryRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        now: _now,
      );

      final delivery = await repository.startDelivery(101);

      expect(delivery.status, DeliveryStatus.onTheWay);
      expect(remote.startAccessToken, 'stored-start-token');
      expect(remote.startedDeliveryId, 101);
      expect(remote.startCalls, 1);
      expect(storage.clearCount, 0);
    });

    test('uses the secure token to submit a location sample', () async {
      final remote = _FakeDeliveryRemoteDataSource(
        recordedLocation: recordedDeliveryLocationFixture(),
      );
      final storage = _MemoryTokenStorage(
        token: const StoredAuthToken(
          accessToken: 'stored-location-token',
          tokenType: 'Bearer',
        ),
      );
      final repository = DeliveryRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        now: _now,
      );
      final sample = deliveryLocationSampleFixture();

      final recorded = await repository.submitLocation(101, sample);

      expect(recorded.latitude, sample.latitude);
      expect(remote.locationCalls, 1);
      expect(remote.locationDeliveryId, 101);
      expect(remote.locationSample, same(sample));
      expect(remote.locationAccessToken, 'stored-location-token');
      expect(storage.clearCount, 0);
    });

    test('uses the secure token to complete the selected delivery', () async {
      final completed = driverDeliveryFixture(status: DeliveryStatus.delivered);
      final remote = _FakeDeliveryRemoteDataSource(
        completedDelivery: completed,
      );
      final storage = _MemoryTokenStorage(
        token: const StoredAuthToken(
          accessToken: 'stored-completion-token',
          tokenType: 'Bearer',
        ),
      );
      final repository = DeliveryRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        now: _now,
      );
      const request = DeliveryCompletionRequest(collectedAmount: 25000);

      final result = await repository.completeDelivery(101, request);

      expect(result.status, DeliveryStatus.delivered);
      expect(remote.completionCalls, 1);
      expect(remote.completedDeliveryId, 101);
      expect(remote.completionRequest, same(request));
      expect(remote.completionAccessToken, 'stored-completion-token');
      expect(storage.clearCount, 0);
    });

    test(
      'preserves completion validation fields and the secure token',
      () async {
        final remote = _FakeDeliveryRemoteDataSource(
          completionError: ApiException(
            message: 'Validation failed',
            statusCode: 422,
            fieldErrors: const {
              'collected_amount': ['The collected amount is required.'],
            },
          ),
        );
        const token = StoredAuthToken(
          accessToken: 'completion-validation-token',
          tokenType: 'Bearer',
        );
        final storage = _MemoryTokenStorage(token: token);
        final repository = DeliveryRepositoryImpl(
          remoteDataSource: remote,
          tokenStorage: storage,
          now: _now,
        );

        await expectLater(
          repository.completeDelivery(
            101,
            const DeliveryCompletionRequest(collectedAmount: 25000),
          ),
          throwsA(
            isA<DeliveryFailure>()
                .having((failure) => failure.statusCode, 'statusCode', 422)
                .having(
                  (failure) => failure.fieldError('collected_amount'),
                  'collected amount error',
                  'The collected amount is required.',
                ),
          ),
        );

        expect(storage.token, same(token));
        expect(storage.clearCount, 0);
      },
    );

    test('clears a token rejected during location submission', () async {
      final remote = _FakeDeliveryRemoteDataSource(
        locationError: ApiException(
          message: 'Unauthenticated.',
          statusCode: 401,
        ),
      );
      final storage = _MemoryTokenStorage(
        token: const StoredAuthToken(
          accessToken: 'revoked-location-token',
          tokenType: 'Bearer',
        ),
      );
      final repository = DeliveryRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        now: _now,
      );

      await expectLater(
        repository.submitLocation(101, deliveryLocationSampleFixture()),
        throwsA(
          isA<DeliveryFailure>().having(
            (failure) => failure.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      expect(storage.token, isNull);
      expect(storage.clearCount, 1);
      expect(remote.locationCalls, 1);
    });

    test(
      'preserves the token and status code after a start conflict',
      () async {
        final remote = _FakeDeliveryRemoteDataSource(
          startError: ApiException(
            message: 'This delivery has already been started.',
            statusCode: 409,
          ),
        );
        const token = StoredAuthToken(
          accessToken: 'conflict-token',
          tokenType: 'Bearer',
        );
        final storage = _MemoryTokenStorage(token: token);
        final repository = DeliveryRepositoryImpl(
          remoteDataSource: remote,
          tokenStorage: storage,
          now: _now,
        );

        await expectLater(
          repository.startDelivery(101),
          throwsA(
            isA<DeliveryFailure>()
                .having((failure) => failure.statusCode, 'statusCode', 409)
                .having(
                  (failure) => failure.message,
                  'message',
                  contains('already been started'),
                ),
          ),
        );

        expect(storage.token, same(token));
        expect(storage.clearCount, 0);
        expect(remote.startCalls, 1);
      },
    );

    test('rejects a missing or expired stored session', () async {
      final noSessionRemote = _FakeDeliveryRemoteDataSource();
      final noSession = DeliveryRepositoryImpl(
        remoteDataSource: noSessionRemote,
        tokenStorage: _MemoryTokenStorage(),
        now: _now,
      );

      await expectLater(
        noSession.fetchAssignedDeliveries(),
        throwsA(
          isA<DeliveryFailure>().having(
            (failure) => failure.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      expect(noSessionRemote.calls, 0);

      final expiredStorage = _MemoryTokenStorage(
        token: StoredAuthToken(
          accessToken: 'expired-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.utc(2026, 8, 16),
        ),
      );
      final expiredRemote = _FakeDeliveryRemoteDataSource();
      final expired = DeliveryRepositoryImpl(
        remoteDataSource: expiredRemote,
        tokenStorage: expiredStorage,
        now: _now,
      );

      await expectLater(
        expired.fetchAssignedDeliveries(),
        throwsA(isA<DeliveryFailure>()),
      );
      expect(expiredStorage.token, isNull);
      expect(expiredStorage.clearCount, 1);
      expect(expiredRemote.calls, 0);
    });

    test('clears a token rejected with 401', () async {
      final remote = _FakeDeliveryRemoteDataSource(
        error: ApiException(message: 'Unauthenticated.', statusCode: 401),
      );
      final storage = _MemoryTokenStorage(
        token: const StoredAuthToken(
          accessToken: 'revoked-token',
          tokenType: 'Bearer',
        ),
      );
      final repository = DeliveryRepositoryImpl(
        remoteDataSource: remote,
        tokenStorage: storage,
        now: _now,
      );

      await expectLater(
        repository.fetchAssignedDeliveries(),
        throwsA(
          isA<DeliveryFailure>()
              .having((failure) => failure.statusCode, 'statusCode', 401)
              .having(
                (failure) => failure.message,
                'message',
                contains('session has expired'),
              ),
        ),
      );
      expect(storage.token, isNull);
      expect(storage.clearCount, 1);
    });

    test(
      'clears a token when the detail request is rejected with 401',
      () async {
        final remote = _FakeDeliveryRemoteDataSource(
          detailError: ApiException(
            message: 'Unauthenticated.',
            statusCode: 401,
          ),
        );
        final storage = _MemoryTokenStorage(
          token: const StoredAuthToken(
            accessToken: 'revoked-detail-token',
            tokenType: 'Bearer',
          ),
        );
        final repository = DeliveryRepositoryImpl(
          remoteDataSource: remote,
          tokenStorage: storage,
          now: _now,
        );

        await expectLater(
          repository.fetchDeliveryDetails(101),
          throwsA(
            isA<DeliveryFailure>()
                .having((failure) => failure.statusCode, 'statusCode', 401)
                .having(
                  (failure) => failure.message,
                  'message',
                  contains('session has expired'),
                ),
          ),
        );
        expect(storage.token, isNull);
        expect(storage.clearCount, 1);
      },
    );

    test(
      'keeps the token when the server is temporarily unavailable',
      () async {
        final remote = _FakeDeliveryRemoteDataSource(
          error: ApiException(
            message: 'PelekaPro is temporarily unavailable. Please try again.',
            statusCode: 503,
          ),
        );
        const token = StoredAuthToken(
          accessToken: 'retryable-token',
          tokenType: 'Bearer',
        );
        final storage = _MemoryTokenStorage(token: token);
        final repository = DeliveryRepositoryImpl(
          remoteDataSource: remote,
          tokenStorage: storage,
          now: _now,
        );

        await expectLater(
          repository.fetchAssignedDeliveries(),
          throwsA(
            isA<DeliveryFailure>().having(
              (failure) => failure.statusCode,
              'statusCode',
              503,
            ),
          ),
        );
        expect(storage.token, same(token));
        expect(storage.clearCount, 0);
      },
    );
  });
}

DateTime _now() => DateTime.utc(2026, 8, 17, 10);

class _FakeDeliveryRemoteDataSource implements DeliveryRemoteDataSource {
  _FakeDeliveryRemoteDataSource({
    this.deliveries = const [],
    this.details,
    this.startedDelivery,
    this.error,
    this.detailError,
    this.startError,
    this.recordedLocation,
    this.locationError,
    this.completedDelivery,
    this.completionError,
  });

  final List<DriverDelivery> deliveries;
  final DriverDeliveryDetails? details;
  final DriverDelivery? startedDelivery;
  final ApiException? error;
  final ApiException? detailError;
  final ApiException? startError;
  final RecordedDeliveryLocation? recordedLocation;
  final ApiException? locationError;
  final DriverDelivery? completedDelivery;
  final ApiException? completionError;
  String? accessToken;
  String? detailAccessToken;
  String? startAccessToken;
  String? locationAccessToken;
  String? completionAccessToken;
  int? deliveryId;
  int? startedDeliveryId;
  int? locationDeliveryId;
  int? completedDeliveryId;
  DeliveryLocationSample? locationSample;
  DeliveryCompletionRequest? completionRequest;
  int calls = 0;
  int detailCalls = 0;
  int startCalls = 0;
  int locationCalls = 0;
  int completionCalls = 0;

  @override
  Future<List<DriverDelivery>> fetchAssignedDeliveries(String token) async {
    calls += 1;
    accessToken = token;
    if (error case final apiError?) {
      throw apiError;
    }
    return deliveries;
  }

  @override
  Future<DriverDeliveryDetails> fetchDeliveryDetails(
    int id,
    String token,
  ) async {
    detailCalls += 1;
    deliveryId = id;
    detailAccessToken = token;
    if (detailError case final apiError?) {
      throw apiError;
    }
    return details ?? driverDeliveryDetailsFixture();
  }

  @override
  Future<DriverDelivery> startDelivery(int id, String token) async {
    startCalls += 1;
    startedDeliveryId = id;
    startAccessToken = token;
    if (startError case final apiError?) {
      throw apiError;
    }
    return startedDelivery ??
        driverDeliveryFixture(id: id, status: DeliveryStatus.onTheWay);
  }

  @override
  Future<RecordedDeliveryLocation> submitLocation(
    int id,
    DeliveryLocationSample sample,
    String token,
  ) async {
    locationCalls += 1;
    locationDeliveryId = id;
    locationSample = sample;
    locationAccessToken = token;
    if (locationError case final apiError?) {
      throw apiError;
    }
    return recordedLocation ?? recordedDeliveryLocationFixture();
  }

  @override
  Future<DriverDelivery> completeDelivery(
    int id,
    DeliveryCompletionRequest request,
    String token,
  ) async {
    completionCalls += 1;
    completedDeliveryId = id;
    completionRequest = request;
    completionAccessToken = token;
    if (completionError case final apiError?) {
      throw apiError;
    }
    return completedDelivery ??
        driverDeliveryFixture(id: id, status: DeliveryStatus.delivered);
  }

  @override
  void close() {}
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({this.token});

  StoredAuthToken? token;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    token = null;
  }

  @override
  Future<StoredAuthToken?> read() async => token;

  @override
  Future<void> save(StoredAuthToken value) async => token = value;
}
