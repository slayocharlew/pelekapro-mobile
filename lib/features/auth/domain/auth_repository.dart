import 'package:pelekapro_mobile/features/auth/domain/auth_session.dart';
import 'package:pelekapro_mobile/features/auth/domain/session_restore_result.dart';

abstract interface class AuthRepository {
  Future<SessionRestoreResult> restoreSession();

  Future<AuthSession> login({required String login, required String password});

  Future<void> logout();

  void close();
}
