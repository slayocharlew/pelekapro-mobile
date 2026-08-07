import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';

enum DeliveryResultType { delivered, failed }

class DeliveryResultScreen extends StatelessWidget {
  const DeliveryResultScreen({
    required this.type,
    required this.deliveryCode,
    required this.onBackToDeliveries,
    super.key,
  });

  final DeliveryResultType type;
  final String deliveryCode;
  final VoidCallback onBackToDeliveries;

  @override
  Widget build(BuildContext context) {
    final isDelivered = type == DeliveryResultType.delivered;
    final color = isDelivered ? AppColors.success : AppColors.postmanOrangeDark;
    final background = isDelivered
        ? AppColors.successSoft
        : AppColors.postmanOrangeSoft;

    return Scaffold(
      key: ValueKey(
        isDelivered ? 'delivered-result-screen' : 'failed-result-screen',
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDelivered
                      ? Icons.check_rounded
                      : Icons.report_gmailerrorred_rounded,
                  color: color,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isDelivered ? 'Delivered' : 'Issue submitted',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isDelivered
                    ? 'Delivery completed successfully'
                    : 'Delivery marked as failed',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                deliveryCode,
                style: const TextStyle(
                  color: AppColors.postmanOrangeDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                key: const ValueKey('back-to-deliveries'),
                label: 'Back to deliveries',
                onPressed: onBackToDeliveries,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
