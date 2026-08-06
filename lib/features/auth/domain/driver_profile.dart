class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.isAvailable,
    required this.currentStatus,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final isAvailable = json['is_available'];
    final currentStatus = json['current_status'];

    if (id is! int || isAvailable is! bool || currentStatus is! String) {
      throw const FormatException('Invalid driver profile.');
    }

    return DriverProfile(
      id: id,
      isAvailable: isAvailable,
      currentStatus: currentStatus,
    );
  }

  final int id;
  final bool isAvailable;
  final String currentStatus;
}
