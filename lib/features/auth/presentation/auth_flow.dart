import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/features/auth/auth_composition.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/presentation/driver_profile_screen.dart';
import 'package:pelekapro_mobile/features/auth/presentation/login_screen.dart';
import 'package:pelekapro_mobile/features/auth/presentation/session_check_screen.dart';
import 'package:pelekapro_mobile/features/auth/presentation/session_controller.dart';
import 'package:pelekapro_mobile/features/auth/presentation/session_error_screen.dart';
import 'package:pelekapro_mobile/features/onboarding/onboarding_screen.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key, this.repository});

  final AuthRepository? repository;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  late final AuthRepository _repository;
  late final SessionController _sessionController;
  late final bool _ownsRepository;

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _repository = widget.repository ?? AuthComposition.createRepository();
    _sessionController = SessionController(_repository)
      ..addListener(_handleControllerChanged);
    unawaited(_sessionController.restore());
  }

  @override
  void dispose() {
    _sessionController
      ..removeListener(_handleControllerChanged)
      ..dispose();

    if (_ownsRepository) {
      _repository.close();
    }

    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_sessionController.status) {
      SessionStatus.checking => const SessionCheckScreen(),
      SessionStatus.onboarding => OnboardingScreen(
        authRepository: _repository,
        onOpenLogin: _sessionController.showLogin,
      ),
      SessionStatus.login => LoginScreen(
        repository: _repository,
        onAuthenticated: _sessionController.acceptAuthenticatedUser,
      ),
      SessionStatus.authenticated => DriverProfileScreen(
        user: _sessionController.user!,
        onRefresh: _sessionController.restore,
      ),
      SessionStatus.failure => SessionErrorScreen(
        message: _sessionController.errorMessage!,
        onRetry: _sessionController.restore,
      ),
    };
  }
}
