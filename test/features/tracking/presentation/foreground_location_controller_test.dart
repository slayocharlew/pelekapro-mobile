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
import 'package:pelekapro_mobile/features/tracking/domain/device_location_source.dart';
import 'package:pelekapro_mobile/features/tracking/presentation/foreground_location_controller.dart';

import '../../../helpers/driver_delivery_fixture.dart';

void main() {
  group('ForegroundLocationController', () {
    test(
      'submits granted foreground samples no faster than every 5 seconds',
      () async {
        var now = DateTime.utc(2026, 8, 17, 8, 15, 30);
        final source = _FakeDeviceLocationSource();
        final repository = _FakeDeliveryRepository();
        final controller = ForegroundLocationController(
          repository: repository,
          source: source,
          deliveryId: 101,
          onUnauthorized: () {},
          now: () => now,
        );
        addTearDown(() async {
          controller.dispose();
          await source.close();
        });

        await controller.start();
        expect(controller.status, ForegroundLocationStatus.waitingForFix);
        expect(source.watchCalls, 1);

        source.emit(deliveryLocationSampleFixture(heading: 135));
        await _flushAsyncWork();
        expect(repository.locationCalls, 1);
        expect(repository.lastDeliveryId, 101);
        expect(controller.status, ForegroundLocationStatus.tracking);
        expect(controller.heading, 135);

        now = now.add(const Duration(seconds: 4));
        source.emit(deliveryLocationSampleFixture(heading: null));
        await _flushAsyncWork();
        expect(repository.locationCalls, 1);
        expect(
          controller.heading,
          135,
          reason: 'A null heading preserves UI direction.',
        );

        now = now.add(const Duration(seconds: 1));
        source.emit(deliveryLocationSampleFixture(heading: 180));
        await _flushAsyncWork();
        expect(repository.locationCalls, 2);
        expect(controller.heading, 180);

        await controller.pause();
        source.emit(deliveryLocationSampleFixture());
        await _flushAsyncWork();
        expect(repository.locationCalls, 2);
        expect(controller.status, ForegroundLocationStatus.paused);
      },
    );

    test(
      'does not watch or submit when permission is denied forever',
      () async {
        final source = _FakeDeviceLocationSource(
          access: DeviceLocationAccess.deniedForever,
        );
        final repository = _FakeDeliveryRepository();
        final controller = ForegroundLocationController(
          repository: repository,
          source: source,
          deliveryId: 101,
          onUnauthorized: () {},
        );
        addTearDown(() async {
          controller.dispose();
          await source.close();
        });

        await controller.start();

        expect(
          controller.status,
          ForegroundLocationStatus.permissionDeniedForever,
        );
        expect(source.watchCalls, 0);
        expect(repository.locationCalls, 0);
        expect(await controller.openAppSettings(), isTrue);
        expect(source.openAppSettingsCalls, 1);
      },
    );

    test(
      'backs off after 429 and resumes with a later device sample',
      () async {
        var now = DateTime.utc(2026, 8, 17, 8, 15, 30);
        final source = _FakeDeviceLocationSource();
        final repository = _FakeDeliveryRepository(
          locationFailures: const [
            DeliveryFailure(message: 'Too many requests.', statusCode: 429),
            null,
          ],
        );
        final controller = ForegroundLocationController(
          repository: repository,
          source: source,
          deliveryId: 101,
          onUnauthorized: () {},
          now: () => now,
        );
        addTearDown(() async {
          controller.dispose();
          await source.close();
        });

        await controller.start();
        source.emit(deliveryLocationSampleFixture());
        await _flushAsyncWork();
        expect(controller.status, ForegroundLocationStatus.throttled);
        expect(repository.locationCalls, 1);

        now = now.add(const Duration(seconds: 59));
        source.emit(deliveryLocationSampleFixture());
        await _flushAsyncWork();
        expect(repository.locationCalls, 1);

        now = now.add(const Duration(seconds: 1));
        source.emit(deliveryLocationSampleFixture());
        await _flushAsyncWork();
        expect(repository.locationCalls, 2);
        expect(controller.status, ForegroundLocationStatus.tracking);
      },
    );

    test(
      'stops tracking and expires the session after a location 401',
      () async {
        final source = _FakeDeviceLocationSource();
        final repository = _FakeDeliveryRepository(
          locationFailures: const [
            DeliveryFailure(message: 'Session expired.', statusCode: 401),
          ],
        );
        var unauthorizedCalls = 0;
        final controller = ForegroundLocationController(
          repository: repository,
          source: source,
          deliveryId: 101,
          onUnauthorized: () => unauthorizedCalls += 1,
        );
        addTearDown(() async {
          controller.dispose();
          await source.close();
        });

        await controller.start();
        source.emit(deliveryLocationSampleFixture());
        await _flushAsyncWork();

        expect(unauthorizedCalls, 1);
        expect(controller.hasActiveStream, isFalse);
        expect(controller.status, ForegroundLocationStatus.paused);
      },
    );

    test(
      'stops and requests reconciliation after a workflow rejection',
      () async {
        final source = _FakeDeviceLocationSource();
        final repository = _FakeDeliveryRepository(
          locationFailures: const [
            DeliveryFailure(
              message: 'Location tracking is not active for this delivery.',
              statusCode: 409,
            ),
          ],
        );
        var rejectionCalls = 0;
        final controller = ForegroundLocationController(
          repository: repository,
          source: source,
          deliveryId: 101,
          onUnauthorized: () {},
          onTrackingRejected: () => rejectionCalls += 1,
        );
        addTearDown(() async {
          controller.dispose();
          await source.close();
        });

        await controller.start();
        source.emit(deliveryLocationSampleFixture());
        await _flushAsyncWork();

        expect(rejectionCalls, 1);
        expect(controller.hasActiveStream, isFalse);
        expect(controller.status, ForegroundLocationStatus.trackingRejected);
        expect(controller.message, isNot(contains('Exception')));
      },
    );
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeDeviceLocationSource implements DeviceLocationSource {
  _FakeDeviceLocationSource({this.access = DeviceLocationAccess.granted});

  final DeviceLocationAccess access;
  final StreamController<DeliveryLocationSample> _controller =
      StreamController<DeliveryLocationSample>.broadcast(sync: true);
  int watchCalls = 0;
  int openAppSettingsCalls = 0;

  void emit(DeliveryLocationSample sample) => _controller.add(sample);

  Future<void> close() => _controller.close();

  @override
  Future<DeviceLocationAccess> ensureAccess() async => access;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls += 1;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Stream<DeliveryLocationSample> watch() {
    watchCalls += 1;
    return _controller.stream;
  }
}

class _FakeDeliveryRepository implements DeliveryRepository {
  _FakeDeliveryRepository({this.locationFailures = const []});

  final List<DeliveryFailure?> locationFailures;
  int locationCalls = 0;
  int? lastDeliveryId;

  @override
  Future<List<DriverDelivery>> fetchAssignedDeliveries() async => const [];

  @override
  Future<DriverDeliveryDetails> fetchDeliveryDetails(int deliveryId) async {
    return driverDeliveryDetailsFixture();
  }

  @override
  Future<DriverDelivery> startDelivery(int deliveryId) async {
    return driverDeliveryFixture(
      id: deliveryId,
      status: DeliveryStatus.onTheWay,
    );
  }

  @override
  Future<RecordedDeliveryLocation> submitLocation(
    int deliveryId,
    DeliveryLocationSample sample,
  ) async {
    locationCalls += 1;
    lastDeliveryId = deliveryId;
    final index = locationCalls - 1;
    if (index < locationFailures.length) {
      final failure = locationFailures[index];
      if (failure != null) {
        throw failure;
      }
    }
    return recordedDeliveryLocationFixture(
      latitude: sample.latitude,
      longitude: sample.longitude,
      accuracy: sample.accuracy,
      speed: sample.speed,
      heading: sample.heading,
      recordedAt: sample.recordedAt,
    );
  }

  @override
  Future<DriverDelivery> completeDelivery(
    int deliveryId,
    DeliveryCompletionRequest request,
  ) async =>
      driverDeliveryFixture(id: deliveryId, status: DeliveryStatus.delivered);

  @override
  void close() {}
}
