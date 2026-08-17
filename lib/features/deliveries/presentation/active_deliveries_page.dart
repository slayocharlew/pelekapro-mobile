import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/assigned_deliveries_controller.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_formatters.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_ui_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/models/delivery_ui_model.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';
import 'package:pelekapro_mobile/shared/widgets/status_badge.dart';

class ActiveDeliveriesPage extends StatelessWidget {
  const ActiveDeliveriesPage({
    required this.controller,
    required this.store,
    required this.onOpenNavigation,
    super.key,
  });

  final AssignedDeliveriesController controller;
  final DeliveryUiStore store;
  final ValueChanged<DeliveryUiModel> onOpenNavigation;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([controller, store]),
        builder: (context, _) {
          final delivery = store.activeDelivery;
          final isLoading =
              store.deliveries.isEmpty &&
              (controller.status == AssignedDeliveriesStatus.initial ||
                  controller.status == AssignedDeliveriesStatus.loading);
          final hasError =
              store.deliveries.isEmpty &&
              controller.status == AssignedDeliveriesStatus.failure;

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              key: const ValueKey('active-deliveries-page'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Active delivery',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('refresh-active-delivery'),
                      onPressed: controller.isBusy ? null : controller.refresh,
                      tooltip: 'Refresh active delivery',
                      icon:
                          controller.status ==
                              AssignedDeliveriesStatus.refreshing
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                const Text(
                  'Continue your current trip',
                  style: TextStyle(color: AppColors.mutedInk, fontSize: 14),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (isLoading)
                  const _ActiveLoading()
                else if (hasError)
                  _ActiveError(
                    message: controller.errorMessage!,
                    onRetry: controller.load,
                  )
                else if (delivery == null)
                  const _NoActiveDelivery()
                else
                  _ActiveDeliveryCard(
                    delivery: delivery,
                    onOpen: () => onOpenNavigation(delivery),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({required this.delivery, required this.onOpen});

  final DeliveryUiModel delivery;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                delivery.code,
                style: const TextStyle(
                  color: AppColors.postmanOrangeDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              StatusBadge(status: delivery.status.apiValue),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            delivery.recipientName,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.postmanOrange,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.dropoffArea,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Updated ${formatDeliveryTime(context, delivery.lastUpdatedAt)}',
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            key: const ValueKey('open-active-navigation'),
            label: 'Open navigation',
            icon: Icons.navigation_outlined,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

class _NoActiveDelivery extends StatelessWidget {
  const _NoActiveDelivery();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 100),
      child: Column(
        children: [
          Icon(Icons.two_wheeler_outlined, size: 46, color: AppColors.mutedInk),
          SizedBox(height: AppSpacing.sm),
          Text(
            'No active delivery',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ActiveLoading extends StatelessWidget {
  const _ActiveLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 100),
      child: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _ActiveError extends StatelessWidget {
  const _ActiveError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: AppColors.mutedInk,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Something went wrong',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const ValueKey('retry-active-deliveries'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
