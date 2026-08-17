import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_ui_store.dart';

import '../../../helpers/driver_delivery_fixture.dart';

void main() {
  group('DeliveryUiStore', () {
    test(
      'starts empty and displays only deliveries received from the server',
      () {
        final store = DeliveryUiStore(now: () => DateTime(2026, 8, 17, 12));
        addTearDown(store.dispose);

        expect(store.deliveries, isEmpty);

        store.replaceFromServer(assignedDeliveriesFixture());

        expect(store.todayCount, 4);
        expect(store.activeCount, 2);
        expect(store.doneCount, 1);
        expect(store.deliveryById(101).recipientName, 'Asha Juma');
        expect(store.deliveryById(101).pickupArea, contains('Kariakoo'));
      },
    );

    test('a server start response selects the active delivery', () {
      final store = DeliveryUiStore()
        ..replaceFromServer(assignedDeliveriesFixture());
      addTearDown(store.dispose);

      store.replaceOneFromServer(
        driverDeliveryFixture(status: DeliveryStatus.onTheWay),
      );

      expect(store.deliveryById(101).status, DeliveryStatus.onTheWay);
      expect(store.activeDelivery?.id, 101);
      expect(store.activeCount, 3);
    });

    test('delivered and failed previews stay inside presentation state', () {
      final store = DeliveryUiStore()
        ..replaceFromServer(assignedDeliveriesFixture());
      addTearDown(store.dispose);

      store.replaceOneFromServer(
        driverDeliveryFixture(status: DeliveryStatus.onTheWay),
      );
      store.previewMarkDelivered(101);
      expect(store.deliveryById(101).status, DeliveryStatus.delivered);
      expect(store.doneCount, 2);

      store.previewReportFailed(102);
      expect(store.deliveryById(102).status, DeliveryStatus.failed);
      expect(store.doneCount, 3);
    });

    test('a server refresh replaces local preview state', () {
      final deliveries = assignedDeliveriesFixture();
      final store = DeliveryUiStore()..replaceFromServer(deliveries);
      addTearDown(store.dispose);

      store.replaceOneFromServer(
        driverDeliveryFixture(status: DeliveryStatus.onTheWay),
      );
      store.previewMarkDelivered(101);
      expect(store.deliveryById(101).status, DeliveryStatus.delivered);

      store.replaceFromServer(deliveries);
      expect(store.deliveryById(101).status, DeliveryStatus.assigned);
    });

    test('fresh detail data replaces only the selected delivery', () {
      final store = DeliveryUiStore()
        ..replaceFromServer(assignedDeliveriesFixture());
      addTearDown(store.dispose);

      store.replaceOneFromServer(
        driverDeliveryFixture(
          id: 101,
          recipientName: 'Updated Recipient',
          status: DeliveryStatus.accepted,
        ),
      );

      expect(store.deliveryById(101).recipientName, 'Updated Recipient');
      expect(store.deliveryById(101).status, DeliveryStatus.accepted);
      expect(store.deliveryById(102).recipientName, 'Neema Joseph');
      expect(store.deliveries, hasLength(4));
    });
  });
}
