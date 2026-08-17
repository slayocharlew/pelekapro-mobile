class DeliveryPayment {
  const DeliveryPayment({
    required this.method,
    required this.amountToCollect,
    required this.deliveryFee,
    this.record,
  });

  final String method;
  final double amountToCollect;
  final double deliveryFee;
  final DeliveryPaymentRecord? record;
}

class DeliveryPaymentRecord {
  const DeliveryPaymentRecord({
    required this.method,
    required this.expectedAmount,
    required this.collectedAmount,
    required this.status,
  });

  final String method;
  final double expectedAmount;
  final double collectedAmount;
  final String status;
}
