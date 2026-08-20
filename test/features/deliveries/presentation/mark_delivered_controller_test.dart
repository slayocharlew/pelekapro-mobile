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
import 'package:pelekapro_mobile/features/deliveries/presentation/mark_delivered_controller.dart';

import '../../../helpers/driver_delivery_fixture.dart';

void main() {
  group('MarkDeliveredController', () {
    test('submits once and exposes the server-completed delivery', () async {
      final completer = Completer<DriverDelivery>();
      final repository = _FakeRepository(completionCompleter: completer);
      final controller = MarkDeliveredController(
        repository,
        onUnauthorized: () {},
      );
      addTearDown(controller.dispose);
      const request = DeliveryCompletionRequest(
        deliveryPin: '123456',
        collectedAmount: 25000,
      );

      final firstSubmission = controller.complete(101, request);
      expect(controller.status, MarkDeliveredStatus.submitting);
      await controller.complete(101, request);
      expect(repository.completionCalls, 1);

      completer.complete(
        driverDeliveryFixture(status: DeliveryStatus.delivered),
      );
      await firstSubmission;

      expect(controller.status, MarkDeliveredStatus.success);
      expect(controller.completedDelivery?.status, DeliveryStatus.delivered);
      expect(repository.lastCompletionRequest, same(request));
    });

    test('preserves server validation fields for the form', () async {
      final repository = _FakeRepository(
        completionFailure: const DeliveryFailure(
          message: 'Validation failed',
          statusCode: 422,
          fieldErrors: {
            'delivery_pin': ['The delivery PIN is incorrect.'],
            'collected_amount': ['The collected amount is required.'],
          },
        ),
      );
      final controller = MarkDeliveredController(
        repository,
        onUnauthorized: () {},
      );
      addTearDown(controller.dispose);

      await controller.complete(
        101,
        const DeliveryCompletionRequest(deliveryPin: '000000'),
      );

      expect(controller.status, MarkDeliveredStatus.failure);
      expect(controller.errorStatusCode, 422);
      expect(
        controller.fieldError('delivery_pin'),
        'The delivery PIN is incorrect.',
      );
      expect(controller.shouldReconcile, isFalse);
    });

    test('reports an expired completion session once', () async {
      var unauthorizedCalls = 0;
      final controller = MarkDeliveredController(
        _FakeRepository(
          completionFailure: const DeliveryFailure(
            message: 'Your session has expired. Sign in again.',
            statusCode: 401,
          ),
        ),
        onUnauthorized: () => unauthorizedCalls += 1,
      );
      addTearDown(controller.dispose);

      await controller.complete(101, const DeliveryCompletionRequest());

      expect(controller.isUnauthorized, isTrue);
      expect(unauthorizedCalls, 1);
    });

    test(
      'reconciles an ambiguous result without repeating completion',
      () async {
        final repository = _FakeRepository(
          completionFailure: const DeliveryFailure(
            message:
                'The request timed out. Check your connection and try again.',
          ),
          details: driverDeliveryDetailsFixture(
            delivery: driverDeliveryFixture(status: DeliveryStatus.delivered),
          ),
        );
        final controller = MarkDeliveredController(
          repository,
          onUnauthorized: () {},
        );
        addTearDown(controller.dispose);

        await controller.complete(101, const DeliveryCompletionRequest());
        final reconciled = await controller.reconcile(101);

        expect(reconciled, isTrue);
        expect(controller.status, MarkDeliveredStatus.success);
        expect(repository.completionCalls, 1);
        expect(repository.detailCalls, 1);
      },
    );

    test(
      'keeps the form open when authoritative state is still active',
      () async {
        final repository = _FakeRepository(
          completionFailure: const DeliveryFailure(
            message: 'This delivery cannot be completed.',
            statusCode: 409,
          ),
          details: driverDeliveryDetailsFixture(
            delivery: driverDeliveryFixture(status: DeliveryStatus.onTheWay),
          ),
        );
        final controller = MarkDeliveredController(
          repository,
          onUnauthorized: () {},
        );
        addTearDown(controller.dispose);

        await controller.complete(101, const DeliveryCompletionRequest());
        final reconciled = await controller.reconcile(101);

        expect(reconciled, isFalse);
        expect(controller.status, MarkDeliveredStatus.failure);
        expect(repository.completionCalls, 1);
        expect(repository.detailCalls, 1);
      },
    );
  });
}

class _FakeRepository implements DeliveryRepository {
  _FakeRepository({
    this.completionCompleter,
    this.completionFailure,
    this.details,
  });

  final Completer<DriverDelivery>? completionCompleter;
  final DeliveryFailure? completionFailure;
  final DriverDeliveryDetails? details;
  int completionCalls = 0;
  int detailCalls = 0;
  DeliveryCompletionRequest? lastCompletionRequest;

  @override
  Future<DriverDelivery> completeDelivery(
    int deliveryId,
    DeliveryCompletionRequest request,
  ) async {
    completionCalls += 1;
    lastCompletionRequest = request;
    if (completionFailure case final failure?) {
      throw failure;
    }
    if (completionCompleter case final completer?) {
      return completer.future;
    }
    return driverDeliveryFixture(
      id: deliveryId,
      status: DeliveryStatus.delivered,
    );
  }

  @override
  Future<DriverDeliveryDetails> fetchDeliveryDetails(int deliveryId) async {
    detailCalls += 1;
    return details ??
        driverDeliveryDetailsFixture(
          delivery: driverDeliveryFixture(
            id: deliveryId,
            status: DeliveryStatus.onTheWay,
          ),
        );
  }

  @override
  Future<List<DriverDelivery>> fetchAssignedDeliveries() async => const [];

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
