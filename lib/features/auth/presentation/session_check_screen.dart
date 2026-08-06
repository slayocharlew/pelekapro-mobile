import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';

class SessionCheckScreen extends StatelessWidget {
  const SessionCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('session-check-screen'),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.postmanOrange,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 38,
                  semanticLabel: 'PelekaPro',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Checking your session…',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                key: ValueKey('session-check-progress'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
