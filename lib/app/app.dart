import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/presentation/auth_flow.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_service.dart';
import 'package:pelekapro_mobile/features/onboarding/onboarding_store.dart';
import 'package:pelekapro_mobile/features/tracking/domain/device_location_source.dart';

class PelekaProApp extends StatelessWidget {
  const PelekaProApp({
    super.key,
    this.authRepository,
    this.deliveryRepository,
    this.deviceLocationSource,
    this.navigationRouteService,
    this.onboardingStore,
    this.loadGoogleMap = true,
  });

  final AuthRepository? authRepository;
  final DeliveryRepository? deliveryRepository;
  final DeviceLocationSource? deviceLocationSource;
  final NavigationRouteService? navigationRouteService;
  final OnboardingStore? onboardingStore;
  final bool loadGoogleMap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PelekaPro',
      theme: AppTheme.light(),
      home: AuthFlow(
        repository: authRepository,
        deliveryRepository: deliveryRepository,
        deviceLocationSource: deviceLocationSource,
        navigationRouteService: navigationRouteService,
        onboardingStore: onboardingStore,
        loadGoogleMap: loadGoogleMap,
      ),
    );
  }
}
