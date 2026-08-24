import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_completion_request.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/start_delivery_controller.dart';
import 'package:pelekapro_mobile/features/tracking/domain/device_location_source.dart';

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

    test('captures a current GPS point for a location-aware start', () async {
      final sample = DeliveryLocationSample(
        latitude: -6.7924,
        longitude: 39.2083,
        accuracy: 7.5,
        recordedAt: DateTime.utc(2026, 8, 24, 10),
      );
      final repository = _FakeRepository();
      final controller = StartDeliveryController(
        repository,
        onUnauthorized: () {},
        locationSource: _FakeLocationSource(sample),
      );
      addTearDown(controller.dispose);

      await controller.start(101);

      expect(controller.status, StartDeliveryStatus.success);
      expect(repository.locationAwareStartCalls, 1);
      expect(repository.lastStartLocation, same(sample));
      expect(repository.startCalls, 0);
    });
  });
}

class _FakeRepository
    implements DeliveryRepository, LocationAwareDeliveryStarter {
  _FakeRepository({this.completer, this.failure});

  final Completer<DriverDelivery>? completer;
  final DeliveryFailure? failure;
  int startCalls = 0;
  int locationAwareStartCalls = 0;
  int? lastDeliveryId;
  DeliveryLocationSample? lastStartLocation;

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
  Future<DriverDelivery> startDeliveryAtLocation(
    int deliveryId,
    DeliveryLocationSample startLocation,
  ) async {
    locationAwareStartCalls += 1;
    lastDeliveryId = deliveryId;
    lastStartLocation = startLocation;
    return driverDeliveryFixture(status: DeliveryStatus.onTheWay);
  }

  @override
  Future<RecordedDeliveryLocation> submitLocation(
    int deliveryId,
    DeliveryLocationSample sample,
  ) async => recordedDeliveryLocationFixture();

  @override
  Future<DriverDelivery> completeDelivery(
    int deliveryId,
    DeliveryCompletionRequest request,
  ) async =>
      driverDeliveryFixture(id: deliveryId, status: DeliveryStatus.delivered);

  @override
  void close() {}
}

class _FakeLocationSource implements DeviceLocationSource {
  const _FakeLocationSource(this.sample);

  final DeliveryLocationSample sample;

  @override
  Future<DeviceLocationAccess> ensureAccess() async =>
      DeviceLocationAccess.granted;

  @override
  Stream<DeliveryLocationSample> watch() => Stream.value(sample);

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}
