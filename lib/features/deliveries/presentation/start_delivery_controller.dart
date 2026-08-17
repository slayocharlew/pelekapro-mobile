import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';

enum StartDeliveryStatus { idle, submitting, success, failure }

class StartDeliveryController extends ChangeNotifier {
  StartDeliveryController(this._repository, {required this.onUnauthorized});

  final DeliveryRepository _repository;
  final VoidCallback onUnauthorized;

  StartDeliveryStatus _status = StartDeliveryStatus.idle;
  DriverDelivery? _startedDelivery;
  String? _errorMessage;
  int? _errorStatusCode;
  bool _disposed = false;

  StartDeliveryStatus get status => _status;
  DriverDelivery? get startedDelivery => _startedDelivery;
  String? get errorMessage => _errorMessage;
  int? get errorStatusCode => _errorStatusCode;
  bool get isSubmitting => _status == StartDeliveryStatus.submitting;
  bool get isUnauthorized => _errorStatusCode == 401;

  Future<void> start(int deliveryId) async {
    if (isSubmitting) {
      return;
    }

    _status = StartDeliveryStatus.submitting;
    _startedDelivery = null;
    _errorMessage = null;
    _errorStatusCode = null;
    notifyListeners();

    try {
      final delivery = await _repository.startDelivery(deliveryId);
      if (_disposed) {
        return;
      }
      _startedDelivery = delivery;
      _status = StartDeliveryStatus.success;
      notifyListeners();
    } on DeliveryFailure catch (failure) {
      if (_disposed) {
        return;
      }
      _status = StartDeliveryStatus.failure;
      _errorMessage = failure.message;
      _errorStatusCode = failure.statusCode;
      notifyListeners();

      if (failure.isUnauthorized) {
        onUnauthorized();
      }
    } on Object {
      if (_disposed) {
        return;
      }
      _status = StartDeliveryStatus.failure;
      _errorMessage = 'Something went wrong. Please try again.';
      _errorStatusCode = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
