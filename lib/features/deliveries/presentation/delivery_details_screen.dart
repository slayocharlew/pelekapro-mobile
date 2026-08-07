import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/active_navigation_screen.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';
import 'package:pelekapro_mobile/shared/widgets/status_badge.dart';

class DeliveryDetailsScreen extends StatelessWidget {
  const DeliveryDetailsScreen({
    required this.deliveryId,
    required this.store,
    required this.onReturnToDeliveries,
    super.key,
  });

  final String deliveryId;
  final DemoDeliveryStore store;
  final VoidCallback onReturnToDeliveries;

  void _openNavigation(BuildContext context, DemoDelivery delivery) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveNavigationScreen(
          deliveryId: delivery.id,
          store: store,
          onReturnToDeliveries: onReturnToDeliveries,
        ),
      ),
    );
  }

  void _startLocally(BuildContext context, DemoDelivery delivery) {
    store.startDelivery(delivery.id);
    _openNavigation(context, store.deliveryById(delivery.id));
  }

  void _showContactPreview(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Contact actions will use live delivery data later.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final delivery = store.deliveryById(deliveryId);
        return Scaffold(
          key: const ValueKey('delivery-details-screen'),
          appBar: AppBar(title: const Text('Delivery details')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              112,
            ),
            children: [
              _DeliveryIdentity(delivery: delivery),
              const SizedBox(height: AppSpacing.md),
              _RouteSummary(delivery: delivery),
              const SizedBox(height: AppSpacing.md),
              _CustomerSection(
                delivery: delivery,
                onContact: () => _showContactPreview(context),
              ),
              const SizedBox(height: AppSpacing.md),
              _DeliveryInformation(delivery: delivery),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: _BottomAction(
              delivery: delivery,
              onStart: () => _startLocally(context, delivery),
              onContinue: () => _openNavigation(context, delivery),
            ),
          ),
        );
      },
    );
  }
}

class _DeliveryIdentity extends StatelessWidget {
  const _DeliveryIdentity({required this.delivery});

  final DemoDelivery delivery;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              delivery.code,
              style: const TextStyle(
                color: AppColors.postmanOrangeDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          StatusBadge(status: delivery.status.apiValue),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.delivery});

  final DemoDelivery delivery;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.alt_route_rounded,
                color: AppColors.postmanOrange,
                size: 22,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Route',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _RouteStop(
            label: 'Pickup',
            area: delivery.pickupArea,
            address: delivery.pickupAddress,
            isPickup: true,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(width: 2, height: 28, color: AppColors.border),
          ),
          _RouteStop(
            label: 'Drop off',
            area: delivery.dropoffArea,
            address: delivery.dropoffAddress,
            isPickup: false,
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.label,
    required this.area,
    required this.address,
    required this.isPickup,
  });

  final String label;
  final String area;
  final String address;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          child: Icon(
            isPickup ? Icons.circle : Icons.location_on_rounded,
            color: AppColors.postmanOrange,
            size: isPickup ? 15 : 19,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                area,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                address,
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({required this.delivery, required this.onContact});

  final DemoDelivery delivery;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.person_outline_rounded,
            color: AppColors.postmanOrange,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer',
                  style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  delivery.recipientName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            onPressed: onContact,
            tooltip: 'Call customer',
            icon: const Icon(Icons.phone_outlined, size: 20),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.outlined(
            onPressed: onContact,
            tooltip: 'Message customer',
            icon: const Icon(Icons.message_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _DeliveryInformation extends StatelessWidget {
  const _DeliveryInformation({required this.delivery});

  final DemoDelivery delivery;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _InformationRow(
            icon: Icons.inventory_2_outlined,
            label: 'Parcel',
            title:
                '${delivery.itemCount} item${delivery.itemCount == 1 ? '' : 's'}',
            subtitle: delivery.itemDescription,
          ),
          const Divider(indent: 52),
          _InformationRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Payment',
            title: _formatTzs(delivery.amountToCollect),
            subtitle: delivery.paymentMethod,
          ),
          const Divider(indent: 52),
          _InformationRow(
            icon: Icons.notes_rounded,
            label: 'Note',
            title: delivery.note,
          ),
        ],
      ),
    );
  }

  String _formatTzs(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      buffer.write(digits[index]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return 'TZS $buffer';
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.postmanOrange, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.delivery,
    required this.onStart,
    required this.onContinue,
  });

  final DemoDelivery delivery;
  final VoidCallback onStart;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (delivery.status.canStart) {
      return PrimaryButton(
        key: const ValueKey('start-delivery-local'),
        label: 'Start delivery',
        onPressed: onStart,
      );
    }

    if (delivery.status.isActive) {
      return PrimaryButton(
        key: const ValueKey('continue-delivery-local'),
        label: 'Continue delivery',
        icon: Icons.navigation_outlined,
        onPressed: onContinue,
      );
    }

    return Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        delivery.status == DemoDeliveryStatus.failed
            ? 'Delivery failed'
            : 'Delivery completed',
        style: const TextStyle(
          color: AppColors.mutedInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
