import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/features/auth/auth_composition.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/presentation/login_screen.dart';
import 'package:pelekapro_mobile/features/auth/presentation/session_check_screen.dart';
import 'package:pelekapro_mobile/features/auth/presentation/session_controller.dart';
import 'package:pelekapro_mobile/features/auth/presentation/session_error_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/delivery_composition.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_service.dart';
import 'package:pelekapro_mobile/features/onboarding/onboarding_screen.dart';
import 'package:pelekapro_mobile/features/onboarding/onboarding_store.dart';
import 'package:pelekapro_mobile/features/shell/presentation/driver_shell.dart';
import 'package:pelekapro_mobile/features/tracking/domain/device_location_source.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({
    super.key,
    this.repository,
    this.deliveryRepository,
    this.deviceLocationSource,
    this.navigationRouteService,
    this.onboardingStore,
    this.loadGoogleMap = true,
  });

  final AuthRepository? repository;
  final DeliveryRepository? deliveryRepository;
  final DeviceLocationSource? deviceLocationSource;
  final NavigationRouteService? navigationRouteService;
  final OnboardingStore? onboardingStore;
  final bool loadGoogleMap;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  late final AuthRepository _repository;
  late final DeliveryRepository _deliveryRepository;
  late final SessionController _sessionController;
  late final OnboardingStore _onboardingStore;
  late final bool _ownsRepository;
  late final bool _ownsDeliveryRepository;
  bool? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _ownsDeliveryRepository = widget.deliveryRepository == null;
    _repository = widget.repository ?? AuthComposition.createRepository();
    _deliveryRepository =
        widget.deliveryRepository ?? DeliveryComposition.createRepository();
    _onboardingStore = widget.onboardingStore ?? SecureOnboardingStore();
    _sessionController = SessionController(_repository)
      ..addListener(_handleControllerChanged);
    unawaited(_loadOnboardingState());
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
    if (_ownsDeliveryRepository) {
      _deliveryRepository.close();
    }

    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadOnboardingState() async {
    var completed = true;

    try {
      completed = await _onboardingStore.isCompleted();
    } on Object {
      // Onboarding storage must never prevent a driver from signing in.
    }

    if (mounted) {
      setState(() => _onboardingCompleted = completed);
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      await _onboardingStore.markCompleted();
    } on Object {
      // Continue to authentication even if the preference cannot be saved.
    }

    if (mounted) {
      setState(() => _onboardingCompleted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingCompleted == null) {
      return const SessionCheckScreen();
    }

    if (!_onboardingCompleted!) {
      return OnboardingScreen(
        authRepository: _repository,
        onOpenLogin: () => unawaited(_completeOnboarding()),
      );
    }

    return switch (_sessionController.status) {
      SessionStatus.checking => const SessionCheckScreen(),
      SessionStatus.login => LoginScreen(
        repository: _repository,
        onAuthenticated: _sessionController.acceptAuthenticatedUser,
      ),
      SessionStatus.authenticated => DriverShell(
        user: _sessionController.user!,
        repository: _repository,
        deliveryRepository: _deliveryRepository,
        onRefreshAccount: _sessionController.restore,
        onSessionExpired: _sessionController.showLogin,
        onLoggedOut: _sessionController.showLogin,
        deviceLocationSource: widget.deviceLocationSource,
        navigationRouteService: widget.navigationRouteService,
        loadGoogleMap: widget.loadGoogleMap,
      ),
      SessionStatus.failure => SessionErrorScreen(
        message: _sessionController.errorMessage!,
        onRetry: _sessionController.restore,
      ),
    };
  }
}
