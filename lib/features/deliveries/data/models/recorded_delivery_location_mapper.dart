import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';

abstract final class RecordedDeliveryLocationMapper {
  static RecordedDeliveryLocation fromJson(Map<String, dynamic> json) {
    final latitude = _requiredDouble(json['latitude'], 'latitude');
    final longitude = _requiredDouble(json['longitude'], 'longitude');
    final accuracy = _optionalDouble(json['accuracy'], 'accuracy');
    final speed = _optionalDouble(json['speed'], 'speed');
    final heading = _optionalDouble(json['heading'], 'heading');
    final batteryLevel = _optionalInt(json['battery_level'], 'battery_level');
    final recordedAt = _requiredDateTime(json['recorded_at'], 'recorded_at');

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        (accuracy != null && accuracy < 0) ||
        (speed != null && speed < 0) ||
        (heading != null && (heading < 0 || heading > 360)) ||
        (batteryLevel != null && (batteryLevel < 0 || batteryLevel > 100))) {
      throw const FormatException('Invalid recorded location values.');
    }

    return RecordedDeliveryLocation(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      speed: speed,
      heading: heading,
      batteryLevel: batteryLevel,
      recordedAt: recordedAt,
    );
  }

  static double _requiredDouble(Object? value, String field) {
    return _optionalDouble(value, field) ??
        (throw FormatException('Missing $field.'));
  }

  static double? _optionalDouble(Object? value, String field) {
    if (value == null) {
      return null;
    }
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('Invalid $field.');
    }
    return parsed;
  }

  static int? _optionalInt(Object? value, String field) {
    if (value == null) {
      return null;
    }
    final parsed = switch (value) {
      int number => number,
      num number when number == number.roundToDouble() => number.toInt(),
      String text => int.tryParse(text),
      _ => null,
    };
    if (parsed == null) {
      throw FormatException('Invalid $field.');
    }
    return parsed;
  }

  static DateTime _requiredDateTime(Object? value, String field) {
    if (value is! String) {
      throw FormatException('Missing $field.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Invalid $field.');
    }
    return parsed.toUtc();
  }
}
