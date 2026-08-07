import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery_fixtures.dart';

class DemoDeliveryStore extends ChangeNotifier {
  DemoDeliveryStore() : _deliveries = List.of(demoDeliveries);

  final List<DemoDelivery> _deliveries;
  String? _activeDeliveryId = 'demo-2';

  List<DemoDelivery> get deliveries => List.unmodifiable(_deliveries);
  int get todayCount => _deliveries.length;
  int get activeCount =>
      _deliveries.where((item) => item.status.isActive).length;
  int get doneCount =>
      13 + _deliveries.where((item) => item.status.isDone).length;

  DemoDelivery? get activeDelivery {
    final activeId = _activeDeliveryId;

    if (activeId != null) {
      for (final delivery in _deliveries) {
        if (delivery.id == activeId && delivery.status.isActive) {
          return delivery;
        }
      }
    }

    for (final delivery in _deliveries) {
      if (delivery.status.isActive) {
        return delivery;
      }
    }

    return null;
  }

  DemoDelivery deliveryById(String id) {
    return _deliveries.firstWhere((delivery) => delivery.id == id);
  }

  void startDelivery(String id) {
    _replaceStatus(id, DemoDeliveryStatus.onTheWay);
    _activeDeliveryId = id;
    notifyListeners();
  }

  void markDelivered(String id) {
    _replaceStatus(id, DemoDeliveryStatus.delivered);
    if (_activeDeliveryId == id) {
      _activeDeliveryId = null;
    }
    notifyListeners();
  }

  void reportFailed(String id) {
    _replaceStatus(id, DemoDeliveryStatus.failed);
    if (_activeDeliveryId == id) {
      _activeDeliveryId = null;
    }
    notifyListeners();
  }

  void _replaceStatus(String id, DemoDeliveryStatus status) {
    final index = _deliveries.indexWhere((delivery) => delivery.id == id);
    if (index == -1) {
      return;
    }
    _deliveries[index] = _deliveries[index].copyWith(status: status);
  }
}
