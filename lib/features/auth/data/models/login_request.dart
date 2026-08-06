class LoginRequest {
  const LoginRequest({
    required this.login,
    required this.password,
    required this.deviceName,
  });

  final String login;
  final String password;
  final String deviceName;

  Map<String, dynamic> toJson() {
    return {'login': login, 'password': password, 'device_name': deviceName};
  }
}
