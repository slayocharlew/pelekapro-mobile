import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/shared/widgets/pelekapro_brand.dart';

class SessionCheckScreen extends StatelessWidget {
  const SessionCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: ValueKey('session-check-screen'),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PelekaProBrand(),
              SizedBox(height: 28),
              SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  key: ValueKey('session-check-progress'),
                  strokeWidth: 2.2,
                  color: AppColors.postmanOrange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
