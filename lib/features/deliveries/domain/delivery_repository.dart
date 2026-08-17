import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';

abstract interface class DeliveryRepository {
  Future<List<DriverDelivery>> fetchAssignedDeliveries();

  Future<DriverDeliveryDetails> fetchDeliveryDetails(int deliveryId);

  Future<DriverDelivery> startDelivery(int deliveryId);

  void close();
}
