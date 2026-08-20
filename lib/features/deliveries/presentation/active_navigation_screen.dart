import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/core/config/app_config.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_details_controller.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_formatters.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_ui_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/mark_delivered_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/models/delivery_ui_model.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/report_issue_screen.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_service.dart';
import 'package:pelekapro_mobile/features/navigation/navigation_composition.dart';
import 'package:pelekapro_mobile/features/navigation/presentation/navigation_route_controller.dart';
import 'package:pelekapro_mobile/features/tracking/data/geolocator_device_location_source.dart';
import 'package:pelekapro_mobile/features/tracking/domain/device_location_source.dart';
import 'package:pelekapro_mobile/features/tracking/presentation/foreground_location_controller.dart';
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
    this.navigationRouteService,
    this.mapTileUrlTemplate,
    this.loadMapTiles = true,
    super.key,
  });

  final int deliveryId;
  final DeliveryUiStore store;
  final DeliveryRepository repository;
  final VoidCallback onSessionExpired;
  final VoidCallback onReturnToDeliveries;
  final DriverDeliveryDetails? initialDetails;
  final DeviceLocationSource? deviceLocationSource;
  final NavigationRouteService? navigationRouteService;
  final String? mapTileUrlTemplate;
  final bool loadMapTiles;

  @override
  State<ActiveNavigationScreen> createState() => _ActiveNavigationScreenState();
}

class _ActiveNavigationScreenState extends State<ActiveNavigationScreen>
    with WidgetsBindingObserver {
  late final DeliveryDetailsController _detailsController;
  late final ForegroundLocationController _locationController;
  late final NavigationRouteService _navigationRouteService;
  late final NavigationRouteController _routeController;
  late final bool _ownsNavigationRouteService;
  var _isForeground = true;
  var _isReconciling = false;
  var _followDriver = true;
  var _followHeading = true;
  var _recenterRequest = 0;

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
    _ownsNavigationRouteService = widget.navigationRouteService == null;
    _navigationRouteService =
        widget.navigationRouteService ??
        NavigationComposition.createRouteService();
    _routeController = NavigationRouteController(_navigationRouteService);
    _detailsController.addListener(_navigationInputChanged);
    _locationController.addListener(_navigationInputChanged);
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
    _detailsController.removeListener(_navigationInputChanged);
    _locationController.removeListener(_navigationInputChanged);
    _routeController.dispose();
    if (_ownsNavigationRouteService) {
      _navigationRouteService.close();
    }
    _locationController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _navigationInputChanged() {
    final origin = _currentCoordinate;
    final destination = _dropoffCoordinate;
    if (origin == null || destination == null) {
      return;
    }
    unawaited(
      _routeController.update(origin: origin, destination: destination),
    );
  }

  NavigationCoordinate? get _currentCoordinate {
    final location = _locationController.latestDeviceLocation;
    if (location == null) {
      return null;
    }
    return NavigationCoordinate(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  NavigationCoordinate? get _dropoffCoordinate {
    final delivery = _detailsController.details?.delivery;
    if (delivery == null) {
      return null;
    }
    return _coordinateFromDelivery(delivery);
  }

  NavigationCoordinate? _coordinateFromDelivery(DriverDelivery delivery) {
    final latitude = delivery.dropoff.latitude;
    final longitude = delivery.dropoff.longitude;
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return NavigationCoordinate(latitude: latitude, longitude: longitude);
  }

  void _recenter() {
    setState(() {
      _followDriver = true;
      _recenterRequest += 1;
    });
  }

  void _toggleCompassMode() {
    setState(() {
      _followHeading = !_followHeading;
      _followDriver = true;
      _recenterRequest += 1;
    });
  }

  void _mapInteractionStarted() {
    if (_followDriver) {
      setState(() => _followDriver = false);
    }
  }

  Future<void> _retryRoute() async {
    final origin = _currentCoordinate;
    final destination = _dropoffCoordinate;
    if (origin == null || destination == null) {
      return;
    }
    await _routeController.retry(origin: origin, destination: destination);
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
          repository: widget.repository,
          onSessionExpired: widget.onSessionExpired,
          onReturnToDeliveries: widget.onReturnToDeliveries,
          lastRecordedLocation: _locationController.lastRecordedLocation,
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
        _routeController,
        widget.store,
      ]),
      builder: (context, _) {
        final delivery = widget.store.deliveryById(widget.deliveryId);
        final destination = _dropoffCoordinate;
        final currentLocation = _currentCoordinate;
        return Scaffold(
          key: const ValueKey('active-navigation-screen'),
          body: Stack(
            children: [
              Positioned.fill(
                child: _NavigationMap(
                  destinationLabel: delivery.dropoffArea.split(',').first,
                  destination: destination,
                  currentLocation: currentLocation,
                  route: _routeController.route,
                  heading: _locationController.heading,
                  tileUrlTemplate: widget.loadMapTiles
                      ? widget.mapTileUrlTemplate ??
                            AppConfig.mapTileUrlTemplate
                      : null,
                  followDriver: _followDriver,
                  followHeading: _followHeading,
                  recenterRequest: _recenterRequest,
                  onInteractionStarted: _mapInteractionStarted,
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
                        destination: delivery.dropoffArea.split(',').first,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _TurnInstruction(
                        destinationAvailable: destination != null,
                        currentLocationAvailable: currentLocation != null,
                        controller: _routeController,
                        onRetry: () => unawaited(_retryRoute()),
                      ),
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
                      icon: _followHeading
                          ? Icons.explore_rounded
                          : Icons.north_rounded,
                      label: _followHeading
                          ? 'Use north-up map'
                          : 'Follow travel direction',
                      onPressed: _toggleCompassMode,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _MapControl(
                      icon: Icons.my_location_rounded,
                      label: 'Recenter',
                      isActive: _followDriver,
                      onPressed: _recenter,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.sm,
                bottom:
                    MediaQuery.sizeOf(context).height * 0.48 + AppSpacing.xs,
                child: _MapAttribution(
                  routeAttributionVisible: _routeController.route != null,
                ),
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
                    routeController: _routeController,
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
  const _NavigationTopBar({required this.onBack, required this.destination});

  final VoidCallback onBack;
  final String destination;

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
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Drop off',
                  style: TextStyle(color: AppColors.mutedInk, fontSize: 11),
                ),
                Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: Icon(
              Icons.location_on_rounded,
              color: AppColors.postmanOrange,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnInstruction extends StatelessWidget {
  const _TurnInstruction({
    required this.destinationAvailable,
    required this.currentLocationAvailable,
    required this.controller,
    required this.onRetry,
  });

  final bool destinationAvailable;
  final bool currentLocationAvailable;
  final NavigationRouteController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final route = controller.route;
    final NavigationGuidance? guidance = route?.guidance;
    final (IconData, String, String, String?) presentation;
    if (!destinationAvailable) {
      presentation = (
        Icons.location_off_outlined,
        'Drop-off pin missing',
        'Ask dispatch to set exact destination coordinates.',
        null,
      );
    } else if (!currentLocationAvailable) {
      presentation = (
        Icons.gps_not_fixed_rounded,
        'Finding your location',
        'Keep device location turned on.',
        null,
      );
    } else if (guidance != null) {
      presentation = (
        _maneuverIcon(guidance.maneuver),
        guidance.instruction,
        guidance.roadName,
        _formatDistance(guidance.distanceMeters),
      );
    } else if (controller.status == NavigationRouteStatus.loading) {
      presentation = (
        Icons.route_rounded,
        'Building the road route',
        'Using your position and the real drop-off pin.',
        null,
      );
    } else {
      presentation = (
        Icons.route_outlined,
        'Road guidance unavailable',
        controller.message ?? 'Showing real map positions only.',
        null,
      );
    }

    final (icon, title, subtitle, distance) = presentation;
    final canRetry =
        destinationAvailable &&
        currentLocationAvailable &&
        controller.isConfigured &&
        controller.status != NavigationRouteStatus.loading;

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
      child: Row(
        children: [
          Icon(icon, color: AppColors.postmanOrange, size: 34),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (distance != null)
            Text(
              distance,
              style: const TextStyle(
                color: AppColors.postmanOrangeDark,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (canRetry)
            IconButton(
              key: const ValueKey('retry-navigation-route'),
              onPressed: onRetry,
              tooltip: 'Retry route',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh_rounded, size: 21),
            ),
        ],
      ),
    );
  }

  static IconData _maneuverIcon(NavigationManeuver maneuver) {
    return switch (maneuver) {
      NavigationManeuver.slightLeft => Icons.turn_slight_left_rounded,
      NavigationManeuver.left => Icons.turn_left_rounded,
      NavigationManeuver.sharpLeft => Icons.turn_sharp_left_rounded,
      NavigationManeuver.slightRight => Icons.turn_slight_right_rounded,
      NavigationManeuver.right => Icons.turn_right_rounded,
      NavigationManeuver.sharpRight => Icons.turn_sharp_right_rounded,
      NavigationManeuver.uTurn => Icons.u_turn_left_rounded,
      NavigationManeuver.merge => Icons.merge_rounded,
      NavigationManeuver.fork => Icons.fork_right_rounded,
      NavigationManeuver.roundabout => Icons.roundabout_right_rounded,
      NavigationManeuver.arrive => Icons.flag_rounded,
      NavigationManeuver.depart ||
      NavigationManeuver.straight => Icons.straight_rounded,
    };
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) {
      final rounded = meters < 100
          ? (meters / 10).round() * 10
          : (meters / 50).round() * 50;
      return '${rounded.clamp(0, 950)} m';
    }
    final kilometers = meters / 1000;
    return '${kilometers < 10 ? kilometers.toStringAsFixed(1) : kilometers.round()} km';
  }
}

class _NavigationMap extends StatefulWidget {
  const _NavigationMap({
    required this.destinationLabel,
    required this.destination,
    required this.currentLocation,
    required this.route,
    required this.heading,
    required this.tileUrlTemplate,
    required this.followDriver,
    required this.followHeading,
    required this.recenterRequest,
    required this.onInteractionStarted,
  });

  final String destinationLabel;
  final NavigationCoordinate? destination;
  final NavigationCoordinate? currentLocation;
  final NavigationRoute? route;
  final double? heading;
  final String? tileUrlTemplate;
  final bool followDriver;
  final bool followHeading;
  final int recenterRequest;
  final VoidCallback onInteractionStarted;

  @override
  State<_NavigationMap> createState() => _NavigationMapState();
}

class _NavigationMapState extends State<_NavigationMap> {
  final _mapController = MapController();
  var _isMapReady = false;
  var _hasCenteredOnDriver = false;

  @override
  void didUpdateWidget(covariant _NavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.followDriver &&
        (oldWidget.currentLocation != widget.currentLocation ||
            oldWidget.heading != widget.heading ||
            oldWidget.followHeading != widget.followHeading ||
            oldWidget.recenterRequest != widget.recenterRequest)) {
      _scheduleFollow();
    } else if (widget.currentLocation == null &&
        oldWidget.destination != widget.destination) {
      _scheduleDestination();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _scheduleFollow() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _followDriver());
  }

  void _scheduleDestination() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDestination());
  }

  void _followDriver() {
    final location = widget.currentLocation;
    if (!mounted || !_isMapReady || location == null) {
      return;
    }
    final zoom = _hasCenteredOnDriver
        ? _mapController.camera.zoom.clamp(15.5, 18.5)
        : 17.0;
    _hasCenteredOnDriver = true;
    _mapController.moveAndRotate(
      _latLng(location),
      zoom,
      widget.followHeading ? widget.heading ?? 0 : 0,
      id: 'follow-driver',
    );
  }

  void _showDestination() {
    final destination = widget.destination;
    if (!mounted || !_isMapReady || destination == null) {
      return;
    }
    _mapController.move(_latLng(destination), 15.5, id: 'show-destination');
  }

  void _handleMapEvent(MapEvent event) {
    if (switch (event.source) {
      MapEventSource.dragStart ||
      MapEventSource.doubleTap ||
      MapEventSource.doubleTapHold ||
      MapEventSource.multiFingerGestureStart ||
      MapEventSource.scrollWheel ||
      MapEventSource.cursorKeyboardRotation => true,
      _ => false,
    }) {
      widget.onInteractionStarted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.currentLocation ??
        widget.destination ??
        const NavigationCoordinate(latitude: -6.7924, longitude: 39.2083);
    final routePoints = widget.route?.geometry
        .map(_latLng)
        .toList(growable: false);
    final markers = <Marker>[
      if (widget.destination case final destination?)
        Marker(
          point: _latLng(destination),
          width: 180,
          height: 90,
          alignment: Alignment.bottomCenter,
          rotate: true,
          child: _DestinationMarker(destination: widget.destinationLabel),
        ),
      if (widget.currentLocation case final currentLocation?)
        Marker(
          point: _latLng(currentLocation),
          width: 48,
          height: 62,
          rotate: true,
          child: Transform.rotate(
            angle: widget.followHeading
                ? 0
                : (widget.heading ?? 0) * math.pi / 180,
            child: const MotorcycleMarker(),
          ),
        ),
    ];

    return Semantics(
      label: 'Live OpenStreetMap navigation to ${widget.destinationLabel}',
      excludeSemantics: true,
      child: ColoredBox(
        color: const Color(0xFFE9ECE8),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _latLng(initial),
            initialZoom: widget.currentLocation != null ? 17 : 15.5,
            initialRotation: widget.followHeading ? widget.heading ?? 0 : 0,
            minZoom: 4,
            maxZoom: 19,
            backgroundColor: const Color(0xFFE9ECE8),
            onMapReady: () {
              _isMapReady = true;
              if (widget.currentLocation != null && widget.followDriver) {
                _scheduleFollow();
              } else {
                _scheduleDestination();
              }
            },
            onMapEvent: _handleMapEvent,
          ),
          children: [
            if (widget.tileUrlTemplate case final tileUrl?)
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'tz.co.pelekapro.mobile',
                maxNativeZoom: 19,
              ),
            if (routePoints != null && routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: AppColors.postmanOrange,
                    borderColor: Colors.white,
                    borderStrokeWidth: 3,
                    strokeWidth: 7,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  static LatLng _latLng(NavigationCoordinate coordinate) {
    return LatLng(coordinate.latitude, coordinate.longitude);
  }
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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
        const Icon(
          Icons.location_on_rounded,
          color: AppColors.postmanOrange,
          size: 38,
        ),
      ],
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppColors.postmanOrangeSoft.withValues(alpha: 0.96)
          : AppColors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        icon: Icon(
          icon,
          size: 21,
          color: isActive ? AppColors.postmanOrangeDark : null,
        ),
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution({required this.routeAttributionVisible});

  final bool routeAttributionVisible;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        routeAttributionVisible
            ? '© OpenStreetMap contributors • Route: OSRM'
            : '© OpenStreetMap contributors',
        style: const TextStyle(color: AppColors.mutedInk, fontSize: 9),
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
    required this.routeController,
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
  final NavigationRouteController routeController;
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
          Row(
            children: [
              Expanded(
                child: _SheetMetric(
                  label: 'Last update',
                  value: formatDeliveryTime(
                    context,
                    locationController.lastRecordedLocation?.recordedAt ??
                        delivery.lastUpdatedAt,
                  ),
                ),
              ),
              if (routeController.route case final route?) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _SheetMetric(
                    key: const ValueKey('live-route-summary'),
                    label: 'ETA & distance',
                    value: _routeSummary(route),
                  ),
                ),
              ],
            ],
          ),
          if (routeController.isRefreshing) ...[
            const SizedBox(height: AppSpacing.xs),
            const LinearProgressIndicator(
              key: ValueKey('navigation-route-refreshing'),
              minHeight: 2,
            ),
          ],
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

  static String _routeSummary(NavigationRoute route) {
    final minutes = (route.durationSeconds / 60).ceil().clamp(1, 999);
    final distance = route.distanceMeters < 1000
        ? '${route.distanceMeters.round()} m'
        : '${(route.distanceMeters / 1000).toStringAsFixed(1)} km';
    return '$minutes min • $distance';
  }
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
      key: const ValueKey('mark-delivered-api'),
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
  const _SheetMetric({required this.label, required this.value, super.key});

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
