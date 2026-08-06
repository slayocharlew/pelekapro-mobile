import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/onboarding/onboarding_screen.dart';

class PelekaProApp extends StatelessWidget {
  const PelekaProApp({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PelekaPro',
      theme: AppTheme.light(),
      home: OnboardingScreen(authRepository: authRepository),
    );
  }
}
