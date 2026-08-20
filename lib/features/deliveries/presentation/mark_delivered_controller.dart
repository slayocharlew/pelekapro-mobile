import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_completion_request.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';

enum MarkDeliveredStatus { idle, submitting, success, failure }

class MarkDeliveredController extends ChangeNotifier {
  MarkDeliveredController(this._repository, {required this.onUnauthorized});

  final DeliveryRepository _repository;
  final VoidCallback onUnauthorized;

  MarkDeliveredStatus _status = MarkDeliveredStatus.idle;
  DriverDelivery? _completedDelivery;
  String? _errorMessage;
  int? _errorStatusCode;
  Map<String, List<String>> _fieldErrors = const {};
  bool _disposed = false;

  MarkDeliveredStatus get status => _status;
  DriverDelivery? get completedDelivery => _completedDelivery;
  String? get errorMessage => _errorMessage;
  int? get errorStatusCode => _errorStatusCode;
  Map<String, List<String>> get fieldErrors => _fieldErrors;
  bool get isSubmitting => _status == MarkDeliveredStatus.submitting;
  bool get isUnauthorized => _errorStatusCode == 401;
  bool get shouldReconcile =>
      _status == MarkDeliveredStatus.failure &&
      (_errorStatusCode == null || _errorStatusCode == 409);

  String? fieldError(String field) {
    final errors = _fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.first;
  }

  Future<void> complete(
    int deliveryId,
    DeliveryCompletionRequest request,
  ) async {
    if (isSubmitting) {
      return;
    }

    _status = MarkDeliveredStatus.submitting;
    _completedDelivery = null;
    _errorMessage = null;
    _errorStatusCode = null;
    _fieldErrors = const {};
    notifyListeners();

    try {
      final delivery = await _repository.completeDelivery(deliveryId, request);
      if (_disposed) {
        return;
      }
      _completedDelivery = delivery;
      _status = MarkDeliveredStatus.success;
      notifyListeners();
    } on DeliveryFailure catch (failure) {
      if (_disposed) {
        return;
      }
      _recordFailure(failure);
    } on Object {
      if (_disposed) {
        return;
      }
      _recordFailure(
        const DeliveryFailure(
          message: 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  Future<bool> reconcile(int deliveryId) async {
    if (!shouldReconcile || _disposed) {
      return false;
    }

    try {
      final details = await _repository.fetchDeliveryDetails(deliveryId);
      if (_disposed || details.delivery.status != DeliveryStatus.delivered) {
        return false;
      }

      _completedDelivery = details.delivery;
      _status = MarkDeliveredStatus.success;
      _errorMessage = null;
      _errorStatusCode = null;
      _fieldErrors = const {};
      notifyListeners();
      return true;
    } on DeliveryFailure catch (failure) {
      if (!_disposed && failure.isUnauthorized) {
        _recordFailure(failure);
      }
      return false;
    } on Object {
      return false;
    }
  }

  void _recordFailure(DeliveryFailure failure) {
    _status = MarkDeliveredStatus.failure;
    _errorMessage = failure.message;
    _errorStatusCode = failure.statusCode;
    _fieldErrors = failure.fieldErrors;
    notifyListeners();

    if (failure.isUnauthorized) {
      onUnauthorized();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
