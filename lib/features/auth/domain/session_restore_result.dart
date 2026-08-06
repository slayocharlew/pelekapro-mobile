import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';

sealed class SessionRestoreResult {
  const SessionRestoreResult();
}

final class RestoredSession extends SessionRestoreResult {
  const RestoredSession(this.user);

  final AuthUser user;
}

final class UnavailableSession extends SessionRestoreResult {
  const UnavailableSession({required this.hadStoredSession});

  final bool hadStoredSession;
}
