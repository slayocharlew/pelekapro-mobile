import 'package:pelekapro_mobile/features/deliveries/domain/delivery_customer.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_item.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_payment.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_requirements.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_stop.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_timestamps.dart';

class DriverDelivery {
  const DriverDelivery({
    required this.id,
    required this.deliveryNumber,
    required this.trackingCode,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.customer,
    required this.customerAddress,
    required this.items,
    required this.payment,
    required this.requirements,
    required this.timestamps,
  });

  final int id;
  final String deliveryNumber;
  final String trackingCode;
  final DeliveryStatus status;
  final DeliveryStop pickup;
  final DeliveryStop dropoff;
  final DeliveryCustomer customer;
  final DeliveryCustomerAddress? customerAddress;
  final List<DeliveryItem> items;
  final DeliveryPayment payment;
  final DeliveryRequirements requirements;
  final DeliveryTimestamps timestamps;
}
