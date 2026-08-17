class DeliveryStop {
  const DeliveryStop({
    required this.name,
    required this.phone,
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String? name;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
}
