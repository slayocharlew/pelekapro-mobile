import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/start_delivery_controller.dart';

import '../../../helpers/driver_delivery_fixture.dart';

void main() {
  group('StartDeliveryController', () {
    test('submits once and exposes the server-started delivery', () async {
      final completer = Completer<DriverDelivery>();
      final repository = _FakeRepository(completer: completer);
      final controller = StartDeliveryController(
        repository,
        onUnauthorized: () {},
      );
      addTearDown(controller.dispose);

      final firstStart = controller.start(101);
      expect(controller.status, StartDeliveryStatus.submitting);
      await controller.start(101);
      expect(repository.startCalls, 1);

      completer.complete(
        driverDeliveryFixture(status: DeliveryStatus.onTheWay),
      );
      await firstStart;

      expect(controller.status, StartDeliveryStatus.success);
      expect(controller.startedDelivery?.status, DeliveryStatus.onTheWay);
      expect(controller.errorMessage, isNull);
      expect(repository.lastDeliveryId, 101);
    });

    test('keeps a conflict available for UI reconciliation', () async {
      final repository = _FakeRepository(
        failure: const DeliveryFailure(
          message: 'This delivery has already been started.',
          statusCode: 409,
        ),
      );
      final controller = StartDeliveryController(
        repository,
        onUnauthorized: () {},
      );
      addTearDown(controller.dispose);

      await controller.start(101);

      expect(controller.status, StartDeliveryStatus.failure);
      expect(controller.errorStatusCode, 409);
      expect(controller.errorMessage, contains('already been started'));
      expect(controller.isUnauthorized, isFalse);
    });

    test('notifies auth flow when the start request is unauthorized', () async {
      var unauthorizedCalls = 0;
      final repository = _FakeRepository(
        failure: const DeliveryFailure(
          message: 'Session expired.',
          statusCode: 401,
        ),
      );
      final controller = StartDeliveryController(
        repository,
        onUnauthorized: () => unauthorizedCalls += 1,
      );
      addTearDown(controller.dispose);

      await controller.start(101);

      expect(controller.status, StartDeliveryStatus.failure);
      expect(controller.isUnauthorized, isTrue);
      expect(unauthorizedCalls, 1);
    });
  });
}

class _FakeRepository implements DeliveryRepository {
  _FakeRepository({this.completer, this.failure});

  final Completer<DriverDelivery>? completer;
  final DeliveryFailure? failure;
  int startCalls = 0;
  int? lastDeliveryId;

  @override
  Future<List<DriverDelivery>> fetchAssignedDeliveries() async => const [];

  @override
  Future<DriverDeliveryDetails> fetchDeliveryDetails(int deliveryId) async {
    return driverDeliveryDetailsFixture();
  }

  @override
  Future<DriverDelivery> startDelivery(int deliveryId) async {
    startCalls += 1;
    lastDeliveryId = deliveryId;
    if (failure case final startFailure?) {
      throw startFailure;
    }
    if (completer case final pending?) {
      return pending.future;
    }
    return driverDeliveryFixture(status: DeliveryStatus.onTheWay);
  }

  @override
  Future<RecordedDeliveryLocation> submitLocation(
    int deliveryId,
    DeliveryLocationSample sample,
  ) async => recordedDeliveryLocationFixture();

  @override
  void close() {}
}
