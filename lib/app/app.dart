import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/onboarding/onboarding_screen.dart';

class PelekaProApp extends StatelessWidget {
  const PelekaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PelekaPro Mobile',
      theme: AppTheme.light(),
      home: const OnboardingScreen(),
    );
  }
}
