enum DemoDeliveryStatus {
  created,
  locationPending,
  locationConfirmed,
  assigned,
  accepted,
  onTheWay,
  arrived,
  delivered,
  failed,
  cancelled,
}

extension DemoDeliveryStatusPresentation on DemoDeliveryStatus {
  String get apiValue => switch (this) {
    DemoDeliveryStatus.created => 'created',
    DemoDeliveryStatus.locationPending => 'location_pending',
    DemoDeliveryStatus.locationConfirmed => 'location_confirmed',
    DemoDeliveryStatus.assigned => 'assigned',
    DemoDeliveryStatus.accepted => 'accepted',
    DemoDeliveryStatus.onTheWay => 'on_the_way',
    DemoDeliveryStatus.arrived => 'arrived',
    DemoDeliveryStatus.delivered => 'delivered',
    DemoDeliveryStatus.failed => 'failed',
    DemoDeliveryStatus.cancelled => 'cancelled',
  };

  bool get canStart =>
      this == DemoDeliveryStatus.assigned ||
      this == DemoDeliveryStatus.accepted;

  bool get isActive =>
      this == DemoDeliveryStatus.onTheWay || this == DemoDeliveryStatus.arrived;

  bool get isDone =>
      this == DemoDeliveryStatus.delivered ||
      this == DemoDeliveryStatus.failed ||
      this == DemoDeliveryStatus.cancelled;
}

class DemoDelivery {
  const DemoDelivery({
    required this.id,
    required this.code,
    required this.recipientName,
    required this.recipientPhone,
    required this.pickupArea,
    required this.pickupAddress,
    required this.dropoffArea,
    required this.dropoffAddress,
    required this.scheduledTime,
    required this.itemCount,
    required this.itemDescription,
    required this.amountToCollect,
    required this.paymentMethod,
    required this.note,
    required this.status,
    required this.lastUpdate,
    required this.eta,
    required this.distance,
  });

  final String id;
  final String code;
  final String recipientName;
  final String recipientPhone;
  final String pickupArea;
  final String pickupAddress;
  final String dropoffArea;
  final String dropoffAddress;
  final String scheduledTime;
  final int itemCount;
  final String itemDescription;
  final int amountToCollect;
  final String paymentMethod;
  final String note;
  final DemoDeliveryStatus status;
  final String lastUpdate;
  final String eta;
  final String distance;

  DemoDelivery copyWith({DemoDeliveryStatus? status}) {
    return DemoDelivery(
      id: id,
      code: code,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      pickupArea: pickupArea,
      pickupAddress: pickupAddress,
      dropoffArea: dropoffArea,
      dropoffAddress: dropoffAddress,
      scheduledTime: scheduledTime,
      itemCount: itemCount,
      itemDescription: itemDescription,
      amountToCollect: amountToCollect,
      paymentMethod: paymentMethod,
      note: note,
      status: status ?? this.status,
      lastUpdate: lastUpdate,
      eta: eta,
      distance: distance,
    );
  }
}
