import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery_store.dart';

void main() {
  group('DemoDeliveryStore', () {
    test('starts with isolated Tanzanian UI fixtures', () {
      final store = DemoDeliveryStore();
      addTearDown(store.dispose);

      expect(store.todayCount, 6);
      expect(store.activeCount, 2);
      expect(store.doneCount, 14);
      expect(store.deliveryById('demo-1').recipientName, 'Asha Juma');
      expect(store.deliveryById('demo-1').pickupArea, contains('Kariakoo'));
    });

    test('start transition is local and selects the active delivery', () {
      final store = DemoDeliveryStore();
      addTearDown(store.dispose);

      store.startDelivery('demo-1');

      expect(store.deliveryById('demo-1').status, DemoDeliveryStatus.onTheWay);
      expect(store.activeDelivery?.id, 'demo-1');
      expect(store.activeCount, 3);
    });

    test('delivered and failed transitions stay inside demo state', () {
      final store = DemoDeliveryStore();
      addTearDown(store.dispose);

      store.startDelivery('demo-1');
      store.markDelivered('demo-1');
      expect(store.deliveryById('demo-1').status, DemoDeliveryStatus.delivered);
      expect(store.doneCount, 15);

      store.reportFailed('demo-2');
      expect(store.deliveryById('demo-2').status, DemoDeliveryStatus.failed);
      expect(store.doneCount, 16);
    });
  });
}
