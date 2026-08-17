class DeliveryItem {
  const DeliveryItem({
    required this.id,
    required this.deliveryId,
    required this.name,
    required this.quantity,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });

  final int id;
  final int deliveryId;
  final String name;
  final int quantity;
  final double amount;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
