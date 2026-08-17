enum DeliveryStatus {
  created('created'),
  locationPending('location_pending'),
  locationConfirmed('location_confirmed'),
  assigned('assigned'),
  accepted('accepted'),
  onTheWay('on_the_way'),
  arrived('arrived'),
  delivered('delivered'),
  failed('failed'),
  cancelled('cancelled');

  const DeliveryStatus(this.apiValue);

  final String apiValue;

  static DeliveryStatus fromApi(String value) {
    return DeliveryStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => throw FormatException('Unknown delivery status: $value'),
    );
  }

  bool get canStart =>
      this == DeliveryStatus.assigned || this == DeliveryStatus.accepted;

  bool get isActive =>
      this == DeliveryStatus.onTheWay || this == DeliveryStatus.arrived;

  bool get isDone =>
      this == DeliveryStatus.delivered ||
      this == DeliveryStatus.failed ||
      this == DeliveryStatus.cancelled;
}
