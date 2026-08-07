import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_failure.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';

class LogoutController extends ChangeNotifier {
  LogoutController(this._repository);

  final AuthRepository _repository;

  bool _isSubmitting = false;
  bool _isDisposed = false;
  String? _errorMessage;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<bool> submit() async {
    if (_isSubmitting) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _notifyIfActive();

    try {
      await _repository.logout();
      return true;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;
      return false;
    } on Object {
      _errorMessage = 'Sign out could not be completed. Please try again.';
      return false;
    } finally {
      _isSubmitting = false;
      _notifyIfActive();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

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
