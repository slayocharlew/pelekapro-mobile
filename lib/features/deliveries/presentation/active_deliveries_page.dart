import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery_store.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';
import 'package:pelekapro_mobile/shared/widgets/status_badge.dart';

class ActiveDeliveriesPage extends StatelessWidget {
  const ActiveDeliveriesPage({
    required this.store,
    required this.onOpenNavigation,
    super.key,
  });

  final DemoDeliveryStore store;
  final ValueChanged<DemoDelivery> onOpenNavigation;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final delivery = store.activeDelivery;
          return ListView(
            key: const ValueKey('active-deliveries-page'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            children: [
              Text(
                'Active delivery',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Text(
                'Continue your current trip',
                style: TextStyle(color: AppColors.mutedInk, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (delivery == null)
                const _NoActiveDelivery()
              else
                _ActiveDeliveryCard(
                  delivery: delivery,
                  onOpen: () => onOpenNavigation(delivery),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({required this.delivery, required this.onOpen});

  final DemoDelivery delivery;
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
                      '${delivery.eta} • ${delivery.distance}',
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
