import 'package:pelekapro_mobile/features/auth/domain/driver_profile.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.businessId,
    required this.name,
    required this.status,
    required this.role,
    this.branchId,
    this.phone,
    this.email,
    this.driverProfile,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final businessId = json['business_id'];
    final branchId = json['branch_id'];
    final name = json['name'];
    final phone = json['phone'];
    final email = json['email'];
    final status = json['status'];
    final role = json['role'];
    final profileJson = json['driver_profile'];

    if (id is! int ||
        businessId is! int ||
        (branchId != null && branchId is! int) ||
        name is! String ||
        (phone != null && phone is! String) ||
        (email != null && email is! String) ||
        status is! String ||
        role is! String ||
        (profileJson != null && profileJson is! Map<String, dynamic>)) {
      throw const FormatException('Invalid authenticated user.');
    }

    return AuthUser(
      id: id,
      businessId: businessId,
      branchId: branchId as int?,
      name: name,
      phone: phone as String?,
      email: email as String?,
      status: status,
      role: role,
      driverProfile: profileJson == null
          ? null
          : DriverProfile.fromJson(profileJson),
    );
  }

  final int id;
  final int businessId;
  final int? branchId;
  final String name;
  final String? phone;
  final String? email;
  final String status;
  final String role;
  final DriverProfile? driverProfile;
}
