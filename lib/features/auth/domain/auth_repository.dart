import 'package:pelekapro_mobile/features/auth/domain/auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login({required String login, required String password});

  void close();
}
