import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';

enum AssignedDeliveriesStatus {
  initial,
  loading,
  refreshing,
  ready,
  empty,
  failure,
}

class AssignedDeliveriesController extends ChangeNotifier {
  AssignedDeliveriesController(
    this._repository, {
    required this.onUnauthorized,
  });

  final DeliveryRepository _repository;
  final VoidCallback onUnauthorized;

  AssignedDeliveriesStatus _status = AssignedDeliveriesStatus.initial;
  List<DriverDelivery> _deliveries = const [];
  String? _errorMessage;
  bool _disposed = false;

  AssignedDeliveriesStatus get status => _status;
  List<DriverDelivery> get deliveries => _deliveries;
  String? get errorMessage => _errorMessage;
  bool get isBusy =>
      _status == AssignedDeliveriesStatus.loading ||
      _status == AssignedDeliveriesStatus.refreshing;

  Future<void> load() => _fetch(isRefresh: false);

  Future<void> refresh() => _fetch(isRefresh: true);

  Future<void> _fetch({required bool isRefresh}) async {
    if (isBusy) {
      return;
    }

    _status = isRefresh && _deliveries.isNotEmpty
        ? AssignedDeliveriesStatus.refreshing
        : AssignedDeliveriesStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final deliveries = await _repository.fetchAssignedDeliveries();
      if (_disposed) {
        return;
      }
      _deliveries = List.unmodifiable(deliveries);
      _status = deliveries.isEmpty
          ? AssignedDeliveriesStatus.empty
          : AssignedDeliveriesStatus.ready;
      _errorMessage = null;
      notifyListeners();
    } on DeliveryFailure catch (failure) {
      if (_disposed) {
        return;
      }
      _status = AssignedDeliveriesStatus.failure;
      _errorMessage = failure.message;
      notifyListeners();

      if (failure.isUnauthorized) {
        onUnauthorized();
      }
    } on Object {
      if (_disposed) {
        return;
      }
      _status = AssignedDeliveriesStatus.failure;
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
