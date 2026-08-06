import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_failure.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_session.dart';

class LoginController extends ChangeNotifier {
  LoginController(this._repository);

  final AuthRepository _repository;

  bool _isSubmitting = false;
  bool _isDisposed = false;
  String? _generalError;
  String? _loginError;
  String? _passwordError;

  bool get isSubmitting => _isSubmitting;
  String? get generalError => _generalError;
  String? get loginError => _loginError;
  String? get passwordError => _passwordError;

  Future<AuthSession?> submit({
    required String login,
    required String password,
  }) async {
    if (_isSubmitting) {
      return null;
    }

    _isSubmitting = true;
    _generalError = null;
    _loginError = null;
    _passwordError = null;
    _notifyIfActive();

    try {
      return await _repository.login(login: login, password: password);
    } on AuthFailure catch (error) {
      _generalError = error.message;
      _loginError = error.firstErrorFor('login');
      _passwordError = error.firstErrorFor('password');
      return null;
    } on Object {
      _generalError = 'Login could not be completed. Please try again.';
      return null;
    } finally {
      _isSubmitting = false;
      _notifyIfActive();
    }
  }

  void clearLoginError() {
    if (_loginError == null && _generalError == null) {
      return;
    }

    _loginError = null;
    _generalError = null;
    _notifyIfActive();
  }

  void clearPasswordError() {
    if (_passwordError == null && _generalError == null) {
      return;
    }

    _passwordError = null;
    _generalError = null;
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
