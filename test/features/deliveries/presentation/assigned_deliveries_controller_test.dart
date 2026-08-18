import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/assigned_deliveries_controller.dart';

import '../../../helpers/driver_delivery_fixture.dart';

void main() {
  group('AssignedDeliveriesController', () {
    test('loads assigned deliveries and exposes ready state', () async {
      final repository = _FakeRepository(assignedDeliveriesFixture());
      final controller = AssignedDeliveriesController(
        repository,
        onUnauthorized: () {},
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.status, AssignedDeliveriesStatus.ready);
      expect(controller.deliveries, hasLength(4));
      expect(controller.errorMessage, isNull);
      expect(repository.calls, 1);
    });

    test('exposes empty and retryable failure states', () async {
      final repository = _FakeRepository(const []);
      final controller = AssignedDeliveriesController(
        repository,
        onUnauthorized: () {},
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.status, AssignedDeliveriesStatus.empty);

      repository.failure = const DeliveryFailure(message: 'Try again.');
      await controller.refresh();
      expect(controller.status, AssignedDeliveriesStatus.failure);
      expect(controller.errorMessage, 'Try again.');
    });

    test('notifies auth flow when the list request is unauthorized', () async {
      var unauthorizedCalls = 0;
      final repository = _FakeRepository(
        const [],
        failure: const DeliveryFailure(
          message: 'Session expired.',
          statusCode: 401,
        ),
      );
      final controller = AssignedDeliveriesController(
        repository,
        onUnauthorized: () => unauthorizedCalls += 1,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.status, AssignedDeliveriesStatus.failure);
      expect(unauthorizedCalls, 1);
    });
  });
}

class _FakeRepository implements DeliveryRepository {
  _FakeRepository(this.deliveries, {this.failure});

  final List<DriverDelivery> deliveries;
  DeliveryFailure? failure;
  int calls = 0;

  @override
  Future<List<DriverDelivery>> fetchAssignedDeliveries() async {
    calls += 1;
    if (failure case final deliveryFailure?) {
      throw deliveryFailure;
    }
    return deliveries;
  }

  @override
  Future<DriverDeliveryDetails> fetchDeliveryDetails(int deliveryId) async {
    return driverDeliveryDetailsFixture(
      delivery: deliveries.firstWhere((delivery) => delivery.id == deliveryId),
    );
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
  ) async => recordedDeliveryLocationFixture();

  @override
  void close() {}
}
