import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_details_controller.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_formatters.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_ui_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/mark_delivered_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/models/delivery_ui_model.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/report_issue_screen.dart';
import 'package:pelekapro_mobile/features/tracking/data/geolocator_device_location_source.dart';
import 'package:pelekapro_mobile/features/tracking/domain/device_location_source.dart';
import 'package:pelekapro_mobile/features/tracking/presentation/foreground_location_controller.dart';
import 'package:pelekapro_mobile/shared/widgets/pelekapro_brand.dart';
import 'package:pelekapro_mobile/shared/widgets/status_badge.dart';

class ActiveNavigationScreen extends StatefulWidget {
  const ActiveNavigationScreen({
    required this.deliveryId,
    required this.store,
    required this.repository,
    required this.onSessionExpired,
    required this.onReturnToDeliveries,
    this.initialDetails,
    this.deviceLocationSource,
    super.key,
  });

  final int deliveryId;
  final DeliveryUiStore store;
  final DeliveryRepository repository;
  final VoidCallback onSessionExpired;
  final VoidCallback onReturnToDeliveries;
  final DriverDeliveryDetails? initialDetails;
  final DeviceLocationSource? deviceLocationSource;

  @override
  State<ActiveNavigationScreen> createState() => _ActiveNavigationScreenState();
}

class _ActiveNavigationScreenState extends State<ActiveNavigationScreen>
    with WidgetsBindingObserver {
  late final DeliveryDetailsController _detailsController;
  late final ForegroundLocationController _locationController;
  var _isMuted = false;
  var _isForeground = true;
  var _isReconciling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isForeground = switch (WidgetsBinding.instance.lifecycleState) {
      AppLifecycleState.paused ||
      AppLifecycleState.detached ||
      AppLifecycleState.hidden => false,
      _ => true,
    };
    _detailsController = DeliveryDetailsController(
      widget.repository,
      onUnauthorized: widget.onSessionExpired,
      initialDetails: widget.initialDetails,
    );
    _locationController = ForegroundLocationController(
      repository: widget.repository,
      source:
          widget.deviceLocationSource ?? const GeolocatorDeviceLocationSource(),
      deliveryId: widget.deliveryId,
      onUnauthorized: widget.onSessionExpired,
      onTrackingRejected: _refreshAfterTrackingRejection,
      onConnectionRestored: _reconcileAndResume,
    );
    if (widget.initialDetails == null) {
      unawaited(_loadDetails());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_syncTrackingWithDetails());
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isForeground = true;
        unawaited(_reconcileAndResume());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isForeground = false;
        unawaited(_locationController.pause());
    }
  }

  Future<void> _loadDetails({bool syncTracking = true}) async {
    await _detailsController.load(widget.deliveryId);
    if (!mounted) {
      return;
    }
    final details = _detailsController.details;
    if (_detailsController.status == DeliveryDetailsStatus.ready &&
        details != null) {
      widget.store.replaceOneFromServer(details.delivery);
      if (syncTracking) {
        await _syncTrackingWithDetails();
      }
    }
  }

  Future<void> _syncTrackingWithDetails() async {
    if (!mounted || !_isForeground) {
      return;
    }
    final delivery = _detailsController.details?.delivery;
    final canTrack =
        delivery != null &&
        delivery.status.isActive &&
        delivery.timestamps.startedAt != null;

    if (canTrack) {
      await _locationController.start();
    } else {
      await _locationController.pause();
    }
  }

  Future<void> _reconcileAndResume() async {
    if (!mounted || !_isForeground || _isReconciling) {
      return;
    }
    _isReconciling = true;
    try {
      await _locationController.pause();
      await _loadDetails(syncTracking: false);
      if (mounted) {
        await _syncTrackingWithDetails();
      }
    } finally {
      _isReconciling = false;
    }
  }

  Future<void> _refreshAfterTrackingRejection() async {
    await _loadDetails(syncTracking: false);
    if (!mounted) {
      return;
    }
    final status = _detailsController.details?.delivery.status;
    if (status != null && status.isDone) {
      widget.onReturnToDeliveries();
    }
  }

  Future<void> _openDelivered(DeliveryUiModel delivery) async {
    unawaited(_locationController.pause());
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarkDeliveredScreen(
          deliveryId: delivery.id,
          store: widget.store,
          onReturnToDeliveries: widget.onReturnToDeliveries,
        ),
      ),
    );
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      await _reconcileAndResume();
    }
  }

  Future<void> _openIssue(DeliveryUiModel delivery) async {
    final details = _detailsController.details;
    if (details == null) {
      return;
    }
    unawaited(_locationController.pause());
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportIssueScreen(
          deliveryId: delivery.id,
          store: widget.store,
          failureReasons: details.failureReasons,
          onReturnToDeliveries: widget.onReturnToDeliveries,
        ),
      ),
    );
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      await _reconcileAndResume();
    }
  }

  Future<void> _openLocationSettings() async {
    final opened = await _locationController.openLocationSettings();
    if (mounted && !opened) {
      _showSettingsError();
    }
  }

  Future<void> _openAppSettings() async {
    final opened = await _locationController.openAppSettings();
    if (mounted && !opened) {
      _showSettingsError();
    }
  }

  void _showSettingsError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Settings could not be opened. Try again.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _detailsController,
        _locationController,
        widget.store,
      ]),
      builder: (context, _) {
        final delivery = widget.store.deliveryById(widget.deliveryId);
        return Scaffold(
          key: const ValueKey('active-navigation-screen'),
          body: Stack(
            children: [
              Positioned.fill(
                child: _NavigationMap(
                  destination: delivery.dropoffArea.split(',').first,
                  heading: _locationController.heading,
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Column(
                    children: [
                      _NavigationTopBar(
                        onBack: () => Navigator.of(context).pop(),
                        onCall: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Calling will use the live customer number later.',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _TurnInstruction(),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.sm,
                top: MediaQuery.paddingOf(context).top + 190,
                child: Column(
                  children: [
                    _MapControl(
                      icon: _isMuted
                          ? Icons.volume_off_outlined
                          : Icons.volume_up_outlined,
                      label: _isMuted ? 'Unmute guidance' : 'Mute guidance',
                      onPressed: () => setState(() => _isMuted = !_isMuted),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const _MapControl(
                      icon: Icons.explore_outlined,
                      label: 'Compass',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const _MapControl(
                      icon: Icons.my_location_rounded,
                      label: 'Recenter',
                    ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.sm,
                bottom: MediaQuery.sizeOf(context).height * 0.45,
                child: const _MapAttribution(),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.48,
                minChildSize: 0.38,
                maxChildSize: 0.72,
                snap: true,
                builder: (context, scrollController) {
                  return _DeliveryNavigationSheet(
                    delivery: delivery,
                    scrollController: scrollController,
                    detailsStatus: _detailsController.status,
                    detailsError: _detailsController.errorMessage,
                    locationController: _locationController,
                    failureReasonsAvailable:
                        _detailsController.details?.failureReasons.isNotEmpty ??
                        false,
                    onRetryDetails: _loadDetails,
                    onRetryLocation: _reconcileAndResume,
                    onOpenAppSettings: _openAppSettings,
                    onOpenLocationSettings: _openLocationSettings,
                    onDelivered: () => unawaited(_openDelivered(delivery)),
                    onIssue: () => unawaited(_openIssue(delivery)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavigationTopBar extends StatelessWidget {
  const _NavigationTopBar({required this.onBack, required this.onCall});

  final VoidCallback onBack;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: PelekaProBrand(compact: true, showMobile: false),
            ),
          ),
          IconButton(
            onPressed: onCall,
            tooltip: 'Call customer',
            icon: const Icon(
              Icons.phone_outlined,
              color: AppColors.postmanOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnInstruction extends StatelessWidget {
  const _TurnInstruction();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.turn_right_rounded,
            color: AppColors.postmanOrange,
            size: 34,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turn right',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Ali Hassan Mwinyi Rd',
                  style: TextStyle(color: AppColors.mutedInk, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            '150 m',
            style: TextStyle(
              color: AppColors.postmanOrangeDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationMap extends StatelessWidget {
  const _NavigationMap({required this.destination, required this.heading});

  final String destination;
  final double? heading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'OpenStreetMap style navigation preview in $destination, Dar es Salaam',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _DarMapPainter()),
              Positioned(
                left: width * 0.52,
                top: height * 0.29,
                child: const _RoadLabel('Ali Hassan Mwinyi Rd'),
              ),
              Positioned(
                left: width * 0.05,
                top: height * 0.37,
                child: const _RoadLabel('Mwai Kibaki Rd'),
              ),
              Positioned(
                left: width * 0.10,
                top: height * 0.31,
                child: Text(
                  destination.toUpperCase(),
                  style: TextStyle(
                    color: Color(0xFF6B7780),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Positioned(
                left: width * 0.56,
                top: height * 0.22,
                child: _DestinationMarker(destination: destination),
              ),
              Positioned(
                left: width * 0.47,
                top: height * 0.43,
                child: Transform.rotate(
                  angle: (heading ?? 0) * math.pi / 180,
                  child: const MotorcycleMarker(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DarMapPainter extends CustomPainter {
  const _DarMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1F2EF),
    );

    final parkPaint = Paint()..color = const Color(0xFFDCEEDB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.68, size.height * 0.18, 150, 105),
        const Radius.circular(28),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.28, 100, 70),
        const Radius.circular(20),
      ),
      parkPaint,
    );

    final minorRoad = Paint()
      ..color = Colors.white
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final roadEdge = Paint()
      ..color = const Color(0xFFE0E2DE)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roads = <Path>[
      Path()
        ..moveTo(-20, size.height * 0.24)
        ..quadraticBezierTo(
          size.width * 0.45,
          size.height * 0.30,
          size.width + 20,
          size.height * 0.20,
        ),
      Path()
        ..moveTo(-20, size.height * 0.40)
        ..quadraticBezierTo(
          size.width * 0.46,
          size.height * 0.36,
          size.width + 20,
          size.height * 0.43,
        ),
      Path()
        ..moveTo(size.width * 0.20, 0)
        ..lineTo(size.width * 0.34, size.height * 0.62),
      Path()
        ..moveTo(size.width * 0.76, 0)
        ..lineTo(size.width * 0.62, size.height * 0.64),
      Path()
        ..moveTo(size.width * 0.08, 0)
        ..lineTo(size.width * 0.87, size.height * 0.60),
    ];

    for (final road in roads) {
      canvas.drawPath(road, roadEdge);
      canvas.drawPath(road, minorRoad);
    }

    final route = Path()
      ..moveTo(size.width * 0.50, size.height * 0.52)
      ..lineTo(size.width * 0.49, size.height * 0.34)
      ..quadraticBezierTo(
        size.width * 0.49,
        size.height * 0.31,
        size.width * 0.54,
        size.height * 0.31,
      )
      ..lineTo(size.width * 0.63, size.height * 0.24);
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.postmanOrange
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MotorcycleMarker extends StatelessWidget {
  const MotorcycleMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Driver motorcycle position',
      excludeSemantics: true,
      child: Container(
        width: 44,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const CustomPaint(painter: _MotorcyclePainter()),
      ),
    );
  }
}

class _MotorcyclePainter extends CustomPainter {
  const _MotorcyclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0xFF343638);
    final orange = Paint()..color = AppColors.postmanOrange;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, 10),
        width: 12,
        height: 15,
      ),
      dark,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - 9),
        width: 13,
        height: 17,
      ),
      dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 17,
          height: 28,
        ),
        const Radius.circular(7),
      ),
      orange,
    );
    canvas.drawCircle(Offset(size.width / 2, 22), 6, dark);
    canvas.drawLine(
      Offset(size.width * 0.25, 17),
      Offset(size.width * 0.75, 17),
      Paint()
        ..color = dark.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_rounded,
          color: AppColors.postmanOrange,
          size: 38,
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destination,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Drop off',
                style: TextStyle(
                  color: AppColors.postmanOrangeDark,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoadLabel extends StatelessWidget {
  const _RoadLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.12,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5F666C),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: IconButton(
        onPressed: onPressed ?? () {},
        tooltip: label,
        icon: Icon(icon, size: 21),
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'OpenStreetMap • UI preview',
        style: TextStyle(color: AppColors.mutedInk, fontSize: 9),
      ),
    );
  }
}

class _DeliveryNavigationSheet extends StatelessWidget {
  const _DeliveryNavigationSheet({
    required this.delivery,
    required this.scrollController,
    required this.detailsStatus,
    required this.detailsError,
    required this.locationController,
    required this.failureReasonsAvailable,
    required this.onRetryDetails,
    required this.onRetryLocation,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
    required this.onDelivered,
    required this.onIssue,
  });

  final DeliveryUiModel delivery;
  final ScrollController scrollController;
  final DeliveryDetailsStatus detailsStatus;
  final String? detailsError;
  final ForegroundLocationController locationController;
  final bool failureReasonsAvailable;
  final VoidCallback onRetryDetails;
  final VoidCallback onRetryLocation;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onDelivered;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        key: const ValueKey('active-navigation-sheet-list'),
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.xs,
          AppSpacing.page,
          AppSpacing.md + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.code,
                      style: const TextStyle(
                        color: AppColors.postmanOrangeDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
              StatusBadge(status: delivery.status.apiValue),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SheetRouteRow(
            icon: Icons.circle,
            label: 'Pickup',
            value: _shortArea(delivery.pickupArea),
          ),
          const SizedBox(height: AppSpacing.xs),
          _SheetRouteRow(
            icon: Icons.location_on_rounded,
            label: 'Drop off',
            value: _shortArea(delivery.dropoffArea),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SheetMetric(
            label: 'Last update',
            value: formatDeliveryTime(
              context,
              locationController.lastRecordedLocation?.recordedAt ??
                  delivery.lastUpdatedAt,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LocationTrackingBanner(
            controller: locationController,
            onRetry: onRetryLocation,
            onOpenAppSettings: onOpenAppSettings,
            onOpenLocationSettings: onOpenLocationSettings,
          ),
          const SizedBox(height: AppSpacing.md),
          const _DeliveryProgress(),
          const SizedBox(height: AppSpacing.md),
          if (detailsStatus == DeliveryDetailsStatus.loading) ...[
            const LinearProgressIndicator(
              key: ValueKey('active-delivery-details-loading'),
              minHeight: 2,
            ),
            const SizedBox(height: AppSpacing.sm),
          ] else if (detailsStatus == DeliveryDetailsStatus.failure) ...[
            _InlineDetailsError(
              message: detailsError ?? 'Delivery details are unavailable.',
              onRetry: onRetryDetails,
            ),
            const SizedBox(height: AppSpacing.sm),
          ] else if (detailsStatus == DeliveryDetailsStatus.ready &&
              !failureReasonsAvailable) ...[
            const Text(
              'No issue reasons are currently available.',
              key: ValueKey('no-failure-reasons'),
              style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _NavigationActions(
            onDelivered:
                detailsStatus == DeliveryDetailsStatus.ready &&
                    delivery.status.isActive
                ? onDelivered
                : null,
            onIssue:
                detailsStatus == DeliveryDetailsStatus.ready &&
                    delivery.status.isActive &&
                    failureReasonsAvailable
                ? onIssue
                : null,
          ),
        ],
      ),
    );
  }

  static String _shortArea(String value) => value.split(',').first;
}

class _LocationTrackingBanner extends StatelessWidget {
  const _LocationTrackingBanner({
    required this.controller,
    required this.onRetry,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
  });

  final ForegroundLocationController controller;
  final VoidCallback onRetry;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation();
    final isWorking =
        controller.status == ForegroundLocationStatus.requestingPermission ||
        controller.status == ForegroundLocationStatus.syncing;

    return Semantics(
      liveRegion: true,
      label: presentation.label,
      child: Container(
        key: ValueKey('location-status-${controller.status.name}'),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: presentation.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (isWorking)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(presentation.icon, color: presentation.color, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                presentation.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: presentation.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (presentation.action case final action?)
              TextButton(
                key: const ValueKey('location-status-action'),
                onPressed: action,
                child: Text(presentation.actionLabel!),
              ),
          ],
        ),
      ),
    );
  }

  _LocationStatusPresentation _presentation() {
    return switch (controller.status) {
      ForegroundLocationStatus.requestingPermission =>
        const _LocationStatusPresentation(
          label: 'Checking location access',
          icon: Icons.location_searching_rounded,
          color: AppColors.info,
          background: AppColors.infoSoft,
        ),
      ForegroundLocationStatus.waitingForFix =>
        const _LocationStatusPresentation(
          label: 'Waiting for GPS signal',
          icon: Icons.location_searching_rounded,
          color: AppColors.info,
          background: AppColors.infoSoft,
        ),
      ForegroundLocationStatus.syncing => const _LocationStatusPresentation(
        label: 'Updating live location',
        icon: Icons.my_location_rounded,
        color: AppColors.success,
        background: AppColors.successSoft,
      ),
      ForegroundLocationStatus.tracking => const _LocationStatusPresentation(
        label: 'Live location on',
        icon: Icons.my_location_rounded,
        color: AppColors.success,
        background: AppColors.successSoft,
      ),
      ForegroundLocationStatus.serviceDisabled => _LocationStatusPresentation(
        label: 'Turn on device location',
        icon: Icons.location_disabled_outlined,
        color: AppColors.postmanOrangeDark,
        background: AppColors.postmanOrangeSoft,
        actionLabel: 'Turn on',
        action: onOpenLocationSettings,
      ),
      ForegroundLocationStatus.permissionDenied => _LocationStatusPresentation(
        label: 'Location permission is needed',
        icon: Icons.location_disabled_outlined,
        color: AppColors.postmanOrangeDark,
        background: AppColors.postmanOrangeSoft,
        actionLabel: 'Allow',
        action: onRetry,
      ),
      ForegroundLocationStatus.permissionDeniedForever =>
        _LocationStatusPresentation(
          label: 'Allow location in Settings',
          icon: Icons.location_disabled_outlined,
          color: AppColors.postmanOrangeDark,
          background: AppColors.postmanOrangeSoft,
          actionLabel: 'Settings',
          action: onOpenAppSettings,
        ),
      ForegroundLocationStatus.throttled => _LocationStatusPresentation(
        label: controller.message ?? 'Location sync paused briefly',
        icon: Icons.schedule_rounded,
        color: AppColors.mutedInk,
        background: AppColors.whiteSmoke,
      ),
      ForegroundLocationStatus.temporarilyUnavailable =>
        _LocationStatusPresentation(
          label: controller.message ?? 'Location sync interrupted',
          icon: Icons.sync_problem_rounded,
          color: AppColors.postmanOrangeDark,
          background: AppColors.postmanOrangeSoft,
          actionLabel: 'Retry',
          action: onRetry,
        ),
      ForegroundLocationStatus.trackingRejected => _LocationStatusPresentation(
        label: controller.message ?? 'Live tracking is no longer active',
        icon: Icons.info_outline_rounded,
        color: AppColors.mutedInk,
        background: AppColors.whiteSmoke,
        actionLabel: 'Refresh',
        action: onRetry,
      ),
      ForegroundLocationStatus.idle ||
      ForegroundLocationStatus.paused => _LocationStatusPresentation(
        label: 'Live location paused',
        icon: Icons.pause_circle_outline_rounded,
        color: AppColors.mutedInk,
        background: AppColors.whiteSmoke,
        actionLabel: 'Retry',
        action: onRetry,
      ),
    };
  }
}

class _LocationStatusPresentation {
  const _LocationStatusPresentation({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    this.actionLabel,
    this.action,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final String? actionLabel;
  final VoidCallback? action;
}

class _InlineDetailsError extends StatelessWidget {
  const _InlineDetailsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('active-delivery-details-error'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.postmanOrangeSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.postmanOrangeDark,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            key: const ValueKey('retry-active-delivery-details'),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _NavigationActions extends StatelessWidget {
  const _NavigationActions({required this.onDelivered, required this.onIssue});

  final VoidCallback? onDelivered;
  final VoidCallback? onIssue;

  @override
  Widget build(BuildContext context) {
    final deliveredButton = FilledButton(
      key: const ValueKey('mark-delivered-local'),
      onPressed: onDelivered,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.successSoft,
        foregroundColor: AppColors.success,
      ),
      child: const _FlexibleButtonLabel(
        icon: Icons.check_circle_outline_rounded,
        label: 'Mark delivered',
      ),
    );
    final issueButton = OutlinedButton(
      key: const ValueKey('report-issue-local'),
      onPressed: onIssue,
      child: const _FlexibleButtonLabel(
        icon: Icons.report_gmailerrorred_outlined,
        label: 'Report issue',
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final usesLargerText =
            MediaQuery.textScalerOf(context).scale(14) > 15.5;
        if (constraints.maxWidth < 340 || usesLargerText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              deliveredButton,
              const SizedBox(height: AppSpacing.xs),
              issueButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: deliveredButton),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: issueButton),
          ],
        );
      },
    );
  }
}

class _FlexibleButtonLabel extends StatelessWidget {
  const _FlexibleButtonLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _SheetRouteRow extends StatelessWidget {
  const _SheetRouteRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.postmanOrange, size: 17),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _SheetMetric extends StatelessWidget {
  const _SheetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.whiteSmoke,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress();

  @override
  Widget build(BuildContext context) {
    const labels = ['Assigned', 'Picked up', 'On the way', 'Delivered'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: index < 3
                        ? AppColors.postmanOrange
                        : AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index < 3
                          ? AppColors.postmanOrange
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: index == 2
                        ? AppColors.postmanOrangeDark
                        : AppColors.mutedInk,
                    fontSize: 9,
                    fontWeight: index == 2 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (index < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: index < 2 ? AppColors.postmanOrange : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}
