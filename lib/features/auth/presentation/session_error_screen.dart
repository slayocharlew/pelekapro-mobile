import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';

class SessionErrorScreen extends StatelessWidget {
  const SessionErrorScreen({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('session-error-screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: AppColors.errorSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off_outlined,
                      color: AppColors.error,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Something went wrong',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    key: const ValueKey('session-retry'),
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
