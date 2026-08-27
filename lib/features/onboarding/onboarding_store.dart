import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class OnboardingStore {
  Future<bool> isCompleted();

  Future<void> markCompleted();
}

class SecureOnboardingStore implements OnboardingStore {
  SecureOnboardingStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _completedKey = 'pelekapro.onboarding.completed';
  static const _completedValue = '1';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> isCompleted() async {
    return await _storage.read(key: _completedKey) == _completedValue;
  }

  @override
  Future<void> markCompleted() {
    return _storage.write(key: _completedKey, value: _completedValue);
  }
}
