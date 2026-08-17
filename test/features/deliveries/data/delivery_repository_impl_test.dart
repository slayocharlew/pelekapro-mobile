import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/core/storage/token_storage.dart';
import 'package:pelekapro_mobile/features/deliveries/data/delivery_remote_data_source.dart';
import 'package:pelekapro_mobile/features/deliveries/data/delivery_repository_impl.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';

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
  _FakeDeliveryRemoteDataSource({this.deliveries = const [], this.error});

  final List<DriverDelivery> deliveries;
  final ApiException? error;
  String? accessToken;
  int calls = 0;

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
