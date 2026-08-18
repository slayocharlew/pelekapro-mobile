class DeliveryLocationSample {
  DeliveryLocationSample({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracy,
    this.speed,
    this.heading,
  }) {
    _requireRange(latitude, -90, 90, 'latitude');
    _requireRange(longitude, -180, 180, 'longitude');
    _requireNonNegative(accuracy, 'accuracy');
    _requireNonNegative(speed, 'speed');
    if (heading case final value?) {
      _requireRange(value, 0, 360, 'heading');
    }
  }

  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': ?accuracy,
      'speed': ?speed,
      'heading': ?heading,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    };
  }

  static void _requireRange(
    double value,
    double minimum,
    double maximum,
    String name,
  ) {
    if (!value.isFinite || value < minimum || value > maximum) {
      throw ArgumentError.value(value, name, 'must be $minimum to $maximum');
    }
  }

  static void _requireNonNegative(double? value, String name) {
    if (value != null && (!value.isFinite || value < 0)) {
      throw ArgumentError.value(value, name, 'must be non-negative');
    }
  }
}
