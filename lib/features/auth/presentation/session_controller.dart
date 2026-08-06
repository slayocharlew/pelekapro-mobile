import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_failure.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';
import 'package:pelekapro_mobile/features/auth/domain/session_restore_result.dart';

enum SessionStatus { checking, onboarding, login, authenticated, failure }

class SessionController extends ChangeNotifier {
  SessionController(this._repository);

  final AuthRepository _repository;

  SessionStatus _status = SessionStatus.checking;
  AuthUser? _user;
  String? _errorMessage;
  bool _isRestoring = false;
  bool _isDisposed = false;

  SessionStatus get status => _status;
  AuthUser? get user => _user;
  String? get errorMessage => _errorMessage;

  Future<void> restore() async {
    if (_isRestoring) {
      return;
    }

    _isRestoring = true;
    _status = SessionStatus.checking;
    _errorMessage = null;
    _notifyIfActive();

    try {
      final result = await _repository.restoreSession();

      switch (result) {
        case RestoredSession(:final user):
          _user = user;
          _status = SessionStatus.authenticated;
        case UnavailableSession(:final hadStoredSession):
          _user = null;
          _status = hadStoredSession
              ? SessionStatus.login
              : SessionStatus.onboarding;
      }
    } on AuthFailure catch (error) {
      _errorMessage = error.message;
      _status = SessionStatus.failure;
    } on Object {
      _errorMessage = 'The session could not be checked. Please try again.';
      _status = SessionStatus.failure;
    } finally {
      _isRestoring = false;
      _notifyIfActive();
    }
  }

  void showLogin() {
    _status = SessionStatus.login;
    _errorMessage = null;
    _notifyIfActive();
  }

  void acceptAuthenticatedUser(AuthUser user) {
    _user = user;
    _status = SessionStatus.authenticated;
    _errorMessage = null;
    _notifyIfActive();
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
