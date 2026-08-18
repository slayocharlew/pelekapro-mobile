class RecordedDeliveryLocation {
  const RecordedDeliveryLocation({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracy,
    this.speed,
    this.heading,
    this.batteryLevel,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final int? batteryLevel;
  final DateTime recordedAt;
}
