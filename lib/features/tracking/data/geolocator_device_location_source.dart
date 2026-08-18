import 'package:geolocator/geolocator.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/tracking/domain/device_location_source.dart';

class GeolocatorDeviceLocationSource implements DeviceLocationSource {
  const GeolocatorDeviceLocationSource();

  @override
  Future<DeviceLocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return DeviceLocationAccess.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => DeviceLocationAccess.granted,
      LocationPermission.deniedForever => DeviceLocationAccess.deniedForever,
      _ => DeviceLocationAccess.denied,
    };
  }

  @override
  Stream<DeliveryLocationSample> watch() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => DeliveryLocationSample(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: _nonNegative(position.accuracy),
        speed: _nonNegative(position.speed),
        heading: _heading(position.heading),
        recordedAt: position.timestamp,
      ),
    );
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static double? _nonNegative(double value) {
    return value.isFinite && value >= 0 ? value : null;
  }

  static double? _heading(double value) {
    return value.isFinite && value >= 0 && value <= 360 ? value : null;
  }
}
