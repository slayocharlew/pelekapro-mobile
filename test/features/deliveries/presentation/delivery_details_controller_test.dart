import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_completion_request.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_details_controller.dart';

import '../../../helpers/driver_delivery_fixture.dart';

void main() {
  group('DeliveryDetailsController', () {
    test('loads the selected delivery and its failure reasons', () async {
      final repository = _FakeRepository(driverDeliveryDetailsFixture());
      final controller = DeliveryDetailsController(
        repository,
        onUnauthorized: () {},
      );
      addTearDown(controller.dispose);

      await controller.load(101);

      expect(controller.status, DeliveryDetailsStatus.ready);
      expect(controller.details?.delivery.id, 101);
      expect(controller.details?.failureReasons, hasLength(5));
      expect(repository.lastDeliveryId, 101);
      expect(repository.detailCalls, 1);
    });

    test('exposes a retryable detail failure', () async {
      final repository = _FakeRepository(
        driverDeliveryDetailsFixture(),
        failure: const DeliveryFailure(message: 'Try again.'),
      );
      final controller = DeliveryDetailsController(
        repository,
        onUnauthorized: () {},
      );
      addTearDown(controller.dispose);

      await controller.load(101);
      expect(controller.status, DeliveryDetailsStatus.failure);
      expect(controller.errorMessage, 'Try again.');

      repository.failure = null;
      await controller.load(101);
      expect(controller.status, DeliveryDetailsStatus.ready);
      expect(repository.detailCalls, 2);
    });

    test('notifies auth flow when detail access is unauthorized', () async {
      var unauthorizedCalls = 0;
      final repository = _FakeRepository(
        driverDeliveryDetailsFixture(),
        failure: const DeliveryFailure(
          message: 'Session expired.',
          statusCode: 401,
        ),
      );
      final controller = DeliveryDetailsController(
        repository,
        onUnauthorized: () => unauthorizedCalls += 1,
      );
      addTearDown(controller.dispose);

      await controller.load(101);

      expect(controller.status, DeliveryDetailsStatus.failure);
      expect(unauthorizedCalls, 1);
    });
  });
}

class _FakeRepository implements DeliveryRepository {
  _FakeRepository(this.details, {this.failure});

  final DriverDeliveryDetails details;
  DeliveryFailure? failure;
  int detailCalls = 0;
  int? lastDeliveryId;

  @override
  Future<List<DriverDelivery>> fetchAssignedDeliveries() async => const [];

  @override
  Future<DriverDeliveryDetails> fetchDeliveryDetails(int deliveryId) async {
    detailCalls += 1;
    lastDeliveryId = deliveryId;
    if (failure case final deliveryFailure?) {
      throw deliveryFailure;
    }
    return details;
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
  Future<DriverDelivery> completeDelivery(
    int deliveryId,
    DeliveryCompletionRequest request,
  ) async =>
      driverDeliveryFixture(id: deliveryId, status: DeliveryStatus.delivered);

  @override
  void close() {}
}
