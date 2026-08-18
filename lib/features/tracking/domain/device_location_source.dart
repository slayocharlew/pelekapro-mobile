import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';

enum DeviceLocationAccess { granted, serviceDisabled, denied, deniedForever }

abstract interface class DeviceLocationSource {
  Future<DeviceLocationAccess> ensureAccess();

  Stream<DeliveryLocationSample> watch();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}
