import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_completion_request.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';

abstract interface class DeliveryRepository {
  Future<List<DriverDelivery>> fetchAssignedDeliveries();

  Future<DriverDeliveryDetails> fetchDeliveryDetails(int deliveryId);

  Future<DriverDelivery> startDelivery(int deliveryId);

  Future<RecordedDeliveryLocation> submitLocation(
    int deliveryId,
    DeliveryLocationSample sample,
  );

  Future<DriverDelivery> completeDelivery(
    int deliveryId,
    DeliveryCompletionRequest request,
  );

  void close();
}
