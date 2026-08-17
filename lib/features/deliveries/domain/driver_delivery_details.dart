import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure_reason.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';

class DriverDeliveryDetails {
  const DriverDeliveryDetails({
    required this.delivery,
    required this.failureReasons,
  });

  final DriverDelivery delivery;
  final List<DeliveryFailureReason> failureReasons;
}
