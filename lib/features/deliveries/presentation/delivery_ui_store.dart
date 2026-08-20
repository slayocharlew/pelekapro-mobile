import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/models/delivery_ui_model.dart';

class DeliveryUiStore extends ChangeNotifier {
  DeliveryUiStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<DeliveryUiModel> _deliveries = [];
  int? _activeDeliveryId;

  List<DeliveryUiModel> get deliveries => List.unmodifiable(_deliveries);

  int get todayCount {
    final today = _now().toLocal();
    return _deliveries.where((delivery) {
      final assignedAt = delivery.assignedAt?.toLocal();
      return assignedAt != null &&
          assignedAt.year == today.year &&
          assignedAt.month == today.month &&
          assignedAt.day == today.day;
    }).length;
  }

  int get activeCount =>
      _deliveries.where((item) => item.status.isActive).length;

  int get doneCount => _deliveries.where((item) => item.status.isDone).length;

  DeliveryUiModel? get activeDelivery {
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

  void replaceFromServer(List<DriverDelivery> deliveries) {
    _deliveries
      ..clear()
      ..addAll(deliveries.map(DeliveryUiModel.fromDomain));

    if (!_deliveries.any(
      (delivery) =>
          delivery.id == _activeDeliveryId && delivery.status.isActive,
    )) {
      _activeDeliveryId = null;
    }
    notifyListeners();
  }

  void replaceOneFromServer(DriverDelivery delivery) {
    final replacement = DeliveryUiModel.fromDomain(delivery);
    final index = _deliveries.indexWhere((item) => item.id == delivery.id);
    if (index == -1) {
      _deliveries.add(replacement);
    } else {
      _deliveries[index] = replacement;
    }

    if (replacement.status.isActive) {
      _activeDeliveryId = delivery.id;
    } else if (_activeDeliveryId == delivery.id) {
      _activeDeliveryId = null;
    }
    notifyListeners();
  }

  DeliveryUiModel deliveryById(int id) {
    return _deliveries.firstWhere((delivery) => delivery.id == id);
  }

  void previewReportFailed(int id) {
    _replaceStatus(id, DeliveryStatus.failed);
    if (_activeDeliveryId == id) {
      _activeDeliveryId = null;
    }
    notifyListeners();
  }

  void _replaceStatus(int id, DeliveryStatus status) {
    final index = _deliveries.indexWhere((delivery) => delivery.id == id);
    if (index == -1) {
      return;
    }
    _deliveries[index] = _deliveries[index].copyWith(status: status);
  }
}
