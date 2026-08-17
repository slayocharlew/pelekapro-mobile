class DeliveryCustomer {
  const DeliveryCustomer({
    required this.id,
    required this.name,
    required this.phone,
  });

  final int id;
  final String name;
  final String phone;
}

class DeliveryCustomerAddress {
  const DeliveryCustomerAddress({
    required this.label,
    required this.region,
    required this.district,
    required this.ward,
    required this.street,
    required this.latitude,
    required this.longitude,
    this.landmark,
    this.buildingInstruction,
  });

  final String? label;
  final String? region;
  final String? district;
  final String? ward;
  final String? street;
  final String? landmark;
  final String? buildingInstruction;
  final double? latitude;
  final double? longitude;
}
