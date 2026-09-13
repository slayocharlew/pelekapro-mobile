import 'dart:math' as math;

import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';

class StableNavigationPose {
  const StableNavigationPose({
    required this.position,
    required this.heading,
    required this.isMoving,
  });

  final NavigationCoordinate? position;
  final double heading;
  final bool isMoving;
}

class NavigationPoseStabilizer {
  NavigationPoseStabilizer({
    this.movingSpeedThreshold = 1,
    this.stationarySpeedThreshold = 0.45,
    this.minimumMovementMeters = 3.5,
    this.minimumBearingDistanceMeters = 4,
    this.minimumStationaryJitterRadiusMeters = 4,
    this.maximumStationaryJitterRadiusMeters = 12,
    this.headingDeadbandDegrees = 3,
    this.maximumHeadingStepDegrees = 65,
  }) : assert(movingSpeedThreshold > stationarySpeedThreshold),
       assert(stationarySpeedThreshold >= 0),
       assert(minimumMovementMeters > 0),
       assert(minimumBearingDistanceMeters > 0),
       assert(minimumStationaryJitterRadiusMeters > 0),
       assert(
         maximumStationaryJitterRadiusMeters >=
             minimumStationaryJitterRadiusMeters,
       ),
       assert(headingDeadbandDegrees >= 0),
       assert(maximumHeadingStepDegrees > 0);

  final double movingSpeedThreshold;
  final double stationarySpeedThreshold;
  final double minimumMovementMeters;
  final double minimumBearingDistanceMeters;
  final double minimumStationaryJitterRadiusMeters;
  final double maximumStationaryJitterRadiusMeters;
  final double headingDeadbandDegrees;
  final double maximumHeadingStepDegrees;

  NavigationCoordinate? _displayPosition;
  NavigationCoordinate? _lastRawPosition;
  NavigationCoordinate? _bearingAnchor;
  double _heading = 0;
  bool _hasTrustedHeading = false;
  bool _isMoving = false;

  StableNavigationPose update({
    required NavigationCoordinate? position,
    required double? heading,
    required double? speedMetersPerSecond,
    required double? accuracyMeters,
  }) {
    if (position == null || !position.isValid) {
      _displayPosition = null;
      _lastRawPosition = null;
      _bearingAnchor = null;
      _isMoving = false;
      return StableNavigationPose(
        position: null,
        heading: _heading,
        isMoving: false,
      );
    }

    final speed = _validNonNegative(speedMetersPerSecond);
    final accuracy = _validNonNegative(accuracyMeters);
    final stepDistance = _lastRawPosition == null
        ? 0.0
        : _distanceMeters(_lastRawPosition!, position);
    final movementDistanceThreshold = math.max(
      minimumMovementMeters,
      math.min(
        accuracy ?? minimumMovementMeters,
        maximumStationaryJitterRadiusMeters,
      ),
    );
    final movementObserved = stepDistance >= movementDistanceThreshold;
    final movementCanBeInferred =
        movementObserved && (speed == null || speed > stationarySpeedThreshold);

    if (speed != null) {
      if (speed >= movingSpeedThreshold ||
          (speed > stationarySpeedThreshold && movementObserved)) {
        _isMoving = true;
      } else if (speed <= stationarySpeedThreshold) {
        // A real zero/near-zero speed is stronger evidence than a GPS position
        // correction, which can jump several metres while the phone is still.
        _isMoving = false;
      }
    } else if (movementCanBeInferred) {
      _isMoving = true;
    } else if (stepDistance < minimumMovementMeters) {
      _isMoving = false;
    }

    _lastRawPosition = position;
    _updateDisplayPosition(position, accuracy);

    if (_isMoving) {
      _updateHeading(
        position: position,
        sensorHeading: _validHeading(heading),
        speedMetersPerSecond: speed,
      );
    } else {
      _bearingAnchor = position;
    }

    return StableNavigationPose(
      position: _displayPosition,
      heading: _heading,
      isMoving: _isMoving,
    );
  }

  void _updateDisplayPosition(
    NavigationCoordinate position,
    double? accuracyMeters,
  ) {
    final current = _displayPosition;
    if (current == null || _isMoving) {
      _displayPosition = position;
      return;
    }

    final jitterRadius = (accuracyMeters ?? minimumStationaryJitterRadiusMeters)
        .clamp(
          minimumStationaryJitterRadiusMeters,
          maximumStationaryJitterRadiusMeters,
        );
    if (_distanceMeters(current, position) > jitterRadius) {
      _displayPosition = position;
    }
  }

  void _updateHeading({
    required NavigationCoordinate position,
    required double? sensorHeading,
    required double? speedMetersPerSecond,
  }) {
    final anchor = _bearingAnchor;
    double? movementHeading;
    if (anchor == null) {
      _bearingAnchor = position;
    } else if (_distanceMeters(anchor, position) >=
        minimumBearingDistanceMeters) {
      movementHeading = _bearingDegrees(anchor, position);
      _bearingAnchor = position;
    }

    final candidate = _headingCandidate(
      sensorHeading: sensorHeading,
      movementHeading: movementHeading,
    );
    if (candidate == null) {
      return;
    }

    if (!_hasTrustedHeading) {
      _heading = candidate;
      _hasTrustedHeading = true;
      return;
    }

    final delta = _shortestHeadingDelta(_heading, candidate);
    if (delta.abs() < headingDeadbandDegrees) {
      return;
    }

    final speedProgress = ((speedMetersPerSecond ?? movingSpeedThreshold) / 12)
        .clamp(0.0, 1.0);
    final steadyCorrectionFactor = 0.24 + (0.16 * speedProgress);
    final turnProgress = ((delta.abs() - 12) / 58).clamp(0.0, 1.0);
    final smoothingFactor =
        steadyCorrectionFactor +
        ((0.72 - steadyCorrectionFactor) * turnProgress);
    final step = (delta * smoothingFactor).clamp(
      -maximumHeadingStepDegrees,
      maximumHeadingStepDegrees,
    );
    _heading = _normalizeHeading(_heading + step);
  }

  static double? _headingCandidate({
    required double? sensorHeading,
    required double? movementHeading,
  }) {
    if (sensorHeading == null) {
      return movementHeading;
    }
    if (movementHeading == null) {
      return sensorHeading;
    }

    final difference = _shortestHeadingDelta(
      movementHeading,
      sensorHeading,
    ).abs();
    if (difference > 45) {
      return movementHeading;
    }
    return _circularBlend(movementHeading, sensorHeading, 0.55);
  }

  static double _circularBlend(double start, double end, double weight) {
    return _normalizeHeading(
      start + (_shortestHeadingDelta(start, end) * weight),
    );
  }

  static double _distanceMeters(
    NavigationCoordinate start,
    NavigationCoordinate end,
  ) {
    const earthRadiusMeters = 6371000.0;
    final startLatitude = _radians(start.latitude);
    final endLatitude = _radians(end.latitude);
    final latitudeDelta = endLatitude - startLatitude;
    final longitudeDelta = _radians(end.longitude - start.longitude);
    final latitudeTerm = math.sin(latitudeDelta / 2);
    final longitudeTerm = math.sin(longitudeDelta / 2);
    final haversine =
        latitudeTerm * latitudeTerm +
        math.cos(startLatitude) *
            math.cos(endLatitude) *
            longitudeTerm *
            longitudeTerm;
    final bounded = haversine.clamp(0.0, 1.0);
    return 2 *
        earthRadiusMeters *
        math.atan2(math.sqrt(bounded), math.sqrt(1 - bounded));
  }

  static double _bearingDegrees(
    NavigationCoordinate start,
    NavigationCoordinate end,
  ) {
    final startLatitude = _radians(start.latitude);
    final endLatitude = _radians(end.latitude);
    final longitudeDelta = _radians(end.longitude - start.longitude);
    final y = math.sin(longitudeDelta) * math.cos(endLatitude);
    final x =
        math.cos(startLatitude) * math.sin(endLatitude) -
        math.sin(startLatitude) *
            math.cos(endLatitude) *
            math.cos(longitudeDelta);
    return _normalizeHeading(math.atan2(y, x) * 180 / math.pi);
  }

  static double _shortestHeadingDelta(double start, double end) {
    return ((_normalizeHeading(end) - _normalizeHeading(start) + 540) % 360) -
        180;
  }

  static double? _validNonNegative(double? value) {
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  static double? _validHeading(double? value) {
    return value != null && value.isFinite ? _normalizeHeading(value) : null;
  }

  static double _normalizeHeading(double heading) {
    return ((heading % 360) + 360) % 360;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
