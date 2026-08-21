import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/navigation/data/android_google_maps_configuration.dart';
import 'package:pelekapro_mobile/features/navigation/domain/google_maps_configuration.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route.dart';

class GoogleNavigationMap extends StatefulWidget {
  const GoogleNavigationMap({
    required this.destinationLabel,
    required this.destination,
    required this.currentLocation,
    required this.route,
    required this.heading,
    required this.loadGoogleMap,
    required this.followDriver,
    required this.followHeading,
    required this.recenterRequest,
    required this.onInteractionStarted,
    this.mapsConfiguration = const AndroidGoogleMapsConfiguration(),
    super.key,
  });

  final String destinationLabel;
  final NavigationCoordinate? destination;
  final NavigationCoordinate? currentLocation;
  final NavigationRoute? route;
  final double? heading;
  final bool loadGoogleMap;
  final bool followDriver;
  final bool followHeading;
  final int recenterRequest;
  final VoidCallback onInteractionStarted;
  final GoogleMapsConfiguration mapsConfiguration;

  @override
  State<GoogleNavigationMap> createState() => _GoogleNavigationMapState();
}

class _GoogleNavigationMapState extends State<GoogleNavigationMap>
    with SingleTickerProviderStateMixin {
  static const _darEsSalaam = NavigationCoordinate(
    latitude: -6.7924,
    longitude: 39.2083,
  );
  static const _movementDuration = Duration(milliseconds: 1100);

  late final AnimationController _movementController;
  GoogleMapController? _mapController;
  BitmapDescriptor? _motorcycleIcon;
  NavigationCoordinate? _animatedLocation;
  NavigationCoordinate? _movementStart;
  NavigationCoordinate? _movementEnd;
  double _animatedHeading = 0;
  double _movementStartHeading = 0;
  double _movementEndHeading = 0;
  bool? _isConfigured;
  bool _programmaticCameraMove = false;
  bool _hasCenteredOnDriver = false;
  double _cameraZoom = 17;
  int _configurationCheck = 0;

  @override
  void initState() {
    super.initState();
    _animatedLocation = widget.currentLocation;
    _animatedHeading = _normalizeHeading(widget.heading ?? 0);
    _movementController = AnimationController(
      vsync: this,
      duration: _movementDuration,
    )..addListener(_updateAnimatedLocation);
    unawaited(_checkConfiguration());
  }

  @override
  void didUpdateWidget(covariant GoogleNavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadGoogleMap != widget.loadGoogleMap ||
        oldWidget.mapsConfiguration != widget.mapsConfiguration) {
      unawaited(_checkConfiguration());
    }

    if (oldWidget.currentLocation != widget.currentLocation ||
        oldWidget.heading != widget.heading) {
      _animatePose(widget.currentLocation, widget.heading);
    }

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
    _configurationCheck += 1;
    _movementController.dispose();
    _mapController = null;
    super.dispose();
  }

  Future<void> _checkConfiguration() async {
    final check = ++_configurationCheck;
    if (!widget.loadGoogleMap) {
      if (mounted) {
        setState(() => _isConfigured = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isConfigured = null);
    }
    final configured = await widget.mapsConfiguration.isConfigured();
    if (!mounted || check != _configurationCheck) {
      return;
    }
    setState(() => _isConfigured = configured);
    if (configured && _motorcycleIcon == null) {
      unawaited(_loadMotorcycleIcon());
    }
  }

  Future<void> _loadMotorcycleIcon() async {
    final icon = await _createMotorcycleIcon();
    if (!mounted) {
      return;
    }
    setState(() => _motorcycleIcon = icon);
  }

  void _animatePose(
    NavigationCoordinate? destination,
    double? destinationHeading,
  ) {
    final targetHeading = _nearestEquivalentHeading(
      _animatedHeading,
      destinationHeading ?? _animatedHeading,
    );
    if (destination == null) {
      _movementController.stop();
      setState(() {
        _movementStart = null;
        _movementEnd = null;
        _animatedLocation = null;
        _animatedHeading = _normalizeHeading(targetHeading);
      });
      return;
    }

    final start = _animatedLocation;
    if (start == null) {
      _movementController.stop();
      setState(() {
        _movementStart = destination;
        _movementEnd = destination;
        _animatedLocation = destination;
        _animatedHeading = _normalizeHeading(targetHeading);
      });
      return;
    }

    _movementController.stop();
    _movementStart = start;
    _movementEnd = destination;
    _movementStartHeading = _animatedHeading;
    _movementEndHeading = targetHeading;
    _movementController.forward(from: 0);
  }

  void _updateAnimatedLocation() {
    final start = _movementStart;
    final end = _movementEnd;
    if (start == null || end == null || !mounted) {
      return;
    }
    final progress = _movementController.value;
    setState(() {
      _animatedLocation = NavigationCoordinate(
        latitude: ui.lerpDouble(start.latitude, end.latitude, progress)!,
        longitude: ui.lerpDouble(start.longitude, end.longitude, progress)!,
      );
      _animatedHeading = _normalizeHeading(
        ui.lerpDouble(_movementStartHeading, _movementEndHeading, progress)!,
      );
    });
  }

  void _scheduleFollow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_followDriver());
    });
  }

  void _scheduleDestination() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showDestination());
    });
  }

  Future<void> _followDriver() async {
    final controller = _mapController;
    final location = widget.currentLocation;
    if (!mounted || controller == null || location == null) {
      return;
    }

    final zoom = _hasCenteredOnDriver ? _cameraZoom.clamp(15.5, 18.5) : 17.0;
    _hasCenteredOnDriver = true;
    await _animateCamera(
      CameraPosition(
        target: _latLng(location),
        zoom: zoom,
        bearing: widget.followHeading ? _normalizedHeading : 0,
        tilt: 42,
      ),
    );
  }

  Future<void> _showDestination() async {
    final controller = _mapController;
    final destination = widget.destination;
    if (!mounted || controller == null || destination == null) {
      return;
    }
    await _animateCamera(
      CameraPosition(target: _latLng(destination), zoom: 15.5),
    );
  }

  Future<void> _animateCamera(CameraPosition position) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    _programmaticCameraMove = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(position),
        duration: _movementDuration,
      );
    } on StateError {
      _programmaticCameraMove = false;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (widget.currentLocation != null && widget.followDriver) {
      _scheduleFollow();
    } else {
      _scheduleDestination();
    }
  }

  void _onCameraMoveStarted() {
    if (!_programmaticCameraMove) {
      widget.onInteractionStarted();
    }
  }

  void _onCameraMove(CameraPosition position) {
    _cameraZoom = position.zoom;
  }

  void _onCameraIdle() {
    _programmaticCameraMove = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isConfigured == null) {
      return const _MapLoadingState();
    }
    if (!_isConfigured!) {
      return const GoogleMapUnavailableState();
    }

    final initial =
        widget.currentLocation ?? widget.destination ?? _darEsSalaam;
    final riderLocation = _animatedLocation ?? widget.currentLocation;

    return Semantics(
      label: 'Live Google Maps navigation to ${widget.destinationLabel}',
      excludeSemantics: true,
      child: GoogleMap(
        key: const ValueKey('active-google-map'),
        initialCameraPosition: CameraPosition(
          target: _latLng(initial),
          zoom: widget.currentLocation != null ? 17 : 15.5,
          bearing: widget.followHeading ? _normalizedHeading : 0,
          tilt: widget.currentLocation != null ? 42 : 0,
        ),
        onMapCreated: _onMapCreated,
        onCameraMoveStarted: _onCameraMoveStarted,
        onCameraMove: _onCameraMove,
        onCameraIdle: _onCameraIdle,
        mapType: MapType.normal,
        minMaxZoomPreference: const MinMaxZoomPreference(4, 20),
        compassEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        trafficEnabled: false,
        indoorViewEnabled: false,
        buildingsEnabled: true,
        fortyFiveDegreeImageryEnabled: false,
        padding: EdgeInsets.only(
          top: 148,
          bottom: MediaQuery.sizeOf(context).height * 0.4,
        ),
        markers: _markers(riderLocation),
        polylines: _polylines,
      ),
    );
  }

  Set<Marker> _markers(NavigationCoordinate? riderLocation) {
    return {
      if (widget.destination case final destination?)
        Marker(
          markerId: const MarkerId('delivery-destination'),
          position: _latLng(destination),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: widget.destinationLabel,
            snippet: 'Drop off',
          ),
          zIndexInt: 1,
        ),
      if ((riderLocation, _motorcycleIcon) case (final location?, final icon?))
        Marker(
          markerId: const MarkerId('driver-motorcycle'),
          position: _latLng(location),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _animatedHeading,
          icon: icon,
          zIndexInt: 2,
        ),
    };
  }

  Set<Polyline> get _polylines {
    final points = widget.route?.geometry.map(_latLng).toList(growable: false);
    if (points == null || points.length < 2) {
      return const {};
    }
    return {
      Polyline(
        polylineId: const PolylineId('route-border'),
        points: points,
        color: Colors.white,
        width: 12,
        zIndex: 1,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
      Polyline(
        polylineId: const PolylineId('delivery-route'),
        points: points,
        color: AppColors.postmanOrange,
        width: 7,
        zIndex: 2,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  double get _normalizedHeading {
    return _normalizeHeading(widget.heading ?? _animatedHeading);
  }

  static double _nearestEquivalentHeading(double start, double target) {
    final normalizedStart = _normalizeHeading(start);
    final normalizedTarget = _normalizeHeading(target);
    final delta = ((normalizedTarget - normalizedStart + 540) % 360) - 180;
    return start + delta;
  }

  static double _normalizeHeading(double heading) =>
      ((heading % 360) + 360) % 360;

  static LatLng _latLng(NavigationCoordinate coordinate) {
    return LatLng(coordinate.latitude, coordinate.longitude);
  }
}

class GoogleMapUnavailableState extends StatelessWidget {
  const GoogleMapUnavailableState({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Google Maps unavailable',
      child: const ColoredBox(
        color: Color(0xFFE9ECE8),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 32, color: AppColors.mutedInk),
                SizedBox(height: 10),
                Text(
                  'Google Maps unavailable',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  'The Android map key is not configured for this build.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedInk, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapLoadingState extends StatelessWidget {
  const _MapLoadingState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE9ECE8),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

Future<BitmapDescriptor> _createMotorcycleIcon() async {
  const logicalSize = Size(44, 58);
  const scale = 3.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);

  final shadow = Paint()..color = Colors.black.withValues(alpha: 0.16);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 5, 40, 51),
      const Radius.circular(20),
    ),
    shadow,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 1, 40, 51),
      const Radius.circular(20),
    ),
    Paint()..color = Colors.white,
  );
  _paintMotorcycle(canvas, logicalSize);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (logicalSize.width * scale).round(),
    (logicalSize.height * scale).round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) {
    throw StateError('Unable to create the motorcycle map marker.');
  }
  return BitmapDescriptor.bytes(
    bytes.buffer.asUint8List(),
    width: logicalSize.width,
    height: logicalSize.height,
  );
}

void _paintMotorcycle(Canvas canvas, Size size) {
  final dark = Paint()..color = const Color(0xFF343638);
  final orange = Paint()..color = AppColors.postmanOrange;

  canvas.drawOval(
    Rect.fromCenter(center: Offset(size.width / 2, 10), width: 12, height: 15),
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
