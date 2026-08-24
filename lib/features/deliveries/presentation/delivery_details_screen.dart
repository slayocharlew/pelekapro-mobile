import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/active_navigation_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_details_controller.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_formatters.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_ui_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/models/delivery_ui_model.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_service.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/start_delivery_controller.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';
import 'package:pelekapro_mobile/shared/widgets/status_badge.dart';
import 'package:pelekapro_mobile/features/tracking/domain/device_location_source.dart';
import 'package:pelekapro_mobile/features/tracking/data/geolocator_device_location_source.dart';

class DeliveryDetailsScreen extends StatefulWidget {
  const DeliveryDetailsScreen({
    required this.deliveryId,
    required this.store,
    required this.repository,
    required this.onSessionExpired,
    required this.onReturnToDeliveries,
    this.deviceLocationSource,
    this.navigationRouteService,
    this.loadGoogleMap = true,
    super.key,
  });

  final int deliveryId;
  final DeliveryUiStore store;
  final DeliveryRepository repository;
  final VoidCallback onSessionExpired;
  final VoidCallback onReturnToDeliveries;
  final DeviceLocationSource? deviceLocationSource;
  final NavigationRouteService? navigationRouteService;
  final bool loadGoogleMap;

  @override
  State<DeliveryDetailsScreen> createState() => _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends State<DeliveryDetailsScreen> {
  late final DeliveryDetailsController _controller;
  late final StartDeliveryController _startController;

  @override
  void initState() {
    super.initState();
    _controller = DeliveryDetailsController(
      widget.repository,
      onUnauthorized: widget.onSessionExpired,
    );
    _startController = StartDeliveryController(
      widget.repository,
      onUnauthorized: widget.onSessionExpired,
      locationSource:
          widget.deviceLocationSource == null ||
              widget.deviceLocationSource is GeolocatorDeviceLocationSource
          ? (widget.deviceLocationSource ??
                const GeolocatorDeviceLocationSource())
          : null,
    );
    unawaited(_loadDetails());
  }

  @override
  void dispose() {
    _controller.dispose();
    _startController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    await _controller.load(widget.deliveryId);
    if (!mounted) {
      return;
    }
    final details = _controller.details;
    if (_controller.status == DeliveryDetailsStatus.ready && details != null) {
      widget.store.replaceOneFromServer(details.delivery);
    }
  }

  void _openNavigation(
    DeliveryUiModel delivery,
    DriverDeliveryDetails details,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveNavigationScreen(
          deliveryId: delivery.id,
          store: widget.store,
          repository: widget.repository,
          initialDetails: details,
          onSessionExpired: widget.onSessionExpired,
          onReturnToDeliveries: widget.onReturnToDeliveries,
          deviceLocationSource: widget.deviceLocationSource,
          navigationRouteService: widget.navigationRouteService,
          loadGoogleMap: widget.loadGoogleMap,
        ),
      ),
    );
  }

  Future<void> _startDelivery(
    DeliveryUiModel delivery,
    DriverDeliveryDetails currentDetails,
  ) async {
    await _startController.start(delivery.id);
    if (!mounted) {
      return;
    }

    final startedDelivery = _startController.startedDelivery;
    if (_startController.status == StartDeliveryStatus.success &&
        startedDelivery != null) {
      final startedDetails = DriverDeliveryDetails(
        delivery: startedDelivery,
        failureReasons: currentDetails.failureReasons,
      );
      widget.store.replaceOneFromServer(startedDelivery);
      _openNavigation(
        widget.store.deliveryById(startedDelivery.id),
        startedDetails,
      );
      return;
    }

    if (_startController.isUnauthorized) {
      return;
    }

    // A timeout or conflict may mean Laravel committed the start even though
    // the POST response did not reach the phone. Reconcile before retrying.
    await _loadDetails();
    if (!mounted || _controller.status != DeliveryDetailsStatus.ready) {
      return;
    }
    final reconciledDetails = _controller.details;
    if (reconciledDetails != null &&
        reconciledDetails.delivery.status.isActive) {
      _openNavigation(
        widget.store.deliveryById(reconciledDetails.delivery.id),
        reconciledDetails,
      );
    }
  }

  void _showContactPreview() {
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
      animation: Listenable.merge([
        _controller,
        _startController,
        widget.store,
      ]),
      builder: (context, _) {
        final details = _controller.details;
        if (_controller.status == DeliveryDetailsStatus.initial ||
            _controller.status == DeliveryDetailsStatus.loading) {
          return const _DeliveryDetailsLoading();
        }
        if (_controller.status == DeliveryDetailsStatus.failure ||
            details == null) {
          return _DeliveryDetailsError(
            message:
                _controller.errorMessage ??
                'The delivery details could not be loaded.',
            onRetry: _loadDetails,
          );
        }

        final delivery = widget.store.deliveryById(widget.deliveryId);
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
                onContact: _showContactPreview,
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
              isStarting: _startController.isSubmitting,
              startError: _startController.errorMessage,
              onStart: () => _startDelivery(delivery, details),
              onContinue: () => _openNavigation(delivery, details),
            ),
          ),
        );
      },
    );
  }
}

class _DeliveryDetailsLoading extends StatelessWidget {
  const _DeliveryDetailsLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('delivery-details-screen'),
      appBar: AppBar(title: const Text('Delivery details')),
      body: const Center(
        child: SizedBox.square(
          key: ValueKey('delivery-details-loading'),
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _DeliveryDetailsError extends StatelessWidget {
  const _DeliveryDetailsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('delivery-details-screen'),
      appBar: AppBar(title: const Text('Delivery details')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.postmanOrange,
                size: 42,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: const TextStyle(color: AppColors.mutedInk),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                key: const ValueKey('retry-delivery-details'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryIdentity extends StatelessWidget {
  const _DeliveryIdentity({required this.delivery});

  final DeliveryUiModel delivery;

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

  final DeliveryUiModel delivery;

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
              if (address.trim().toLowerCase() !=
                  area.trim().toLowerCase()) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  address,
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
    );
  }
}

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({required this.delivery, required this.onContact});

  final DeliveryUiModel delivery;
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

  final DeliveryUiModel delivery;

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
            title: formatTzs(delivery.amountToCollect),
            subtitle: delivery.paymentMethod,
          ),
          if (delivery.note case final note?) ...[
            const Divider(indent: 52),
            _InformationRow(
              icon: Icons.notes_rounded,
              label: 'Delivery instruction',
              title: note,
            ),
          ],
        ],
      ),
    );
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
    required this.isStarting,
    required this.startError,
    required this.onStart,
    required this.onContinue,
  });

  final DeliveryUiModel delivery;
  final bool isStarting;
  final String? startError;
  final VoidCallback onStart;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (delivery.status.canStart) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (startError case final message?) ...[
            Container(
              key: const ValueKey('start-delivery-error'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.postmanOrangeSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                message,
                style: const TextStyle(color: AppColors.ink, fontSize: 13),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          PrimaryButton(
            key: const ValueKey('start-delivery-api'),
            label: 'Start delivery',
            isLoading: isStarting,
            onPressed: onStart,
          ),
        ],
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
        switch (delivery.status) {
          DeliveryStatus.delivered => 'Delivery completed',
          DeliveryStatus.failed => 'Delivery failed',
          DeliveryStatus.cancelled => 'Delivery cancelled',
          _ => 'Delivery not ready',
        },
        style: const TextStyle(
          color: AppColors.mutedInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
