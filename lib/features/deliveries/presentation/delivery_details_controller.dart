import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';

enum DeliveryDetailsStatus { initial, loading, ready, failure }

class DeliveryDetailsController extends ChangeNotifier {
  DeliveryDetailsController(
    this._repository, {
    required this.onUnauthorized,
    DriverDeliveryDetails? initialDetails,
  }) : _details = initialDetails,
       _status = initialDetails == null
           ? DeliveryDetailsStatus.initial
           : DeliveryDetailsStatus.ready;

  final DeliveryRepository _repository;
  final VoidCallback onUnauthorized;

  DeliveryDetailsStatus _status;
  DriverDeliveryDetails? _details;
  String? _errorMessage;
  bool _disposed = false;

  DeliveryDetailsStatus get status => _status;
  DriverDeliveryDetails? get details => _details;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DeliveryDetailsStatus.loading;

  Future<void> load(int deliveryId) async {
    if (isLoading) {
      return;
    }

    _status = DeliveryDetailsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final details = await _repository.fetchDeliveryDetails(deliveryId);
      if (_disposed) {
        return;
      }
      _details = details;
      _status = DeliveryDetailsStatus.ready;
      notifyListeners();
    } on DeliveryFailure catch (failure) {
      if (_disposed) {
        return;
      }
      _status = DeliveryDetailsStatus.failure;
      _errorMessage = failure.message;
      notifyListeners();

      if (failure.isUnauthorized) {
        onUnauthorized();
      }
    } on Object {
      if (_disposed) {
        return;
      }
      _status = DeliveryDetailsStatus.failure;
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
