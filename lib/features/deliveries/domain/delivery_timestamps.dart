class DeliveryTimestamps {
  const DeliveryTimestamps({
    required this.assignedAt,
    required this.startedAt,
    required this.arrivedAt,
    required this.deliveredAt,
    required this.failedAt,
    required this.cancelledAt,
  });

  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? arrivedAt;
  final DateTime? deliveredAt;
  final DateTime? failedAt;
  final DateTime? cancelledAt;

  DateTime? get latest {
    final values = [
      assignedAt,
      startedAt,
      arrivedAt,
      deliveredAt,
      failedAt,
      cancelledAt,
    ].whereType<DateTime>().toList(growable: false);

    if (values.isEmpty) {
      return null;
    }

    values.sort();
    return values.last;
  }
}
