import 'package:flutter/services.dart';
import 'package:pelekapro_mobile/features/navigation/domain/google_maps_configuration.dart';

class AndroidGoogleMapsConfiguration implements GoogleMapsConfiguration {
  const AndroidGoogleMapsConfiguration();

  static const _channel = MethodChannel(
    'tz.co.pelekapro.mobile/google_maps_configuration',
  );

  @override
  Future<bool> isConfigured() async {
    try {
      return await _channel.invokeMethod<bool>('isConfigured') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
