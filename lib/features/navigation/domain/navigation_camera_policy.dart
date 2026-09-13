import 'dart:math' as math;

import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';

class NavigationCameraProfile {
  const NavigationCameraProfile({
    required this.zoom,
    required this.tilt,
    required this.lookAheadMeters,
  });

  final double zoom;
  final double tilt;
  final double lookAheadMeters;
}

abstract final class NavigationCameraPolicy {
  static const _maximumProfileSpeedMetersPerSecond = 25.0;

  static NavigationCameraProfile profileFor(double? speedMetersPerSecond) {
    final speed = _safeSpeed(speedMetersPerSecond);
    final progress = (speed / _maximumProfileSpeedMetersPerSecond).clamp(
      0.0,
      1.0,
    );
    final easedProgress = math.pow(progress, 0.75).toDouble();

    return NavigationCameraProfile(
      zoom: _lerp(18.8, 17.2, easedProgress),
      tilt: _lerp(46, 56, progress),
      lookAheadMeters: _lerp(14, 85, progress),
    );
  }

  static NavigationCoordinate lookAhead({
    required NavigationCoordinate origin,
    required double headingDegrees,
    required double distanceMeters,
  }) {
    if (!origin.isValid ||
        !headingDegrees.isFinite ||
        !distanceMeters.isFinite ||
        distanceMeters <= 0) {
      return origin;
    }

    const earthRadiusMeters = 6371000.0;
    final angularDistance = distanceMeters / earthRadiusMeters;
    final heading = _degreesToRadians(_normalizeHeading(headingDegrees));
    final latitude = _degreesToRadians(origin.latitude);
    final longitude = _degreesToRadians(origin.longitude);

    final projectedLatitude = math.asin(
      math.sin(latitude) * math.cos(angularDistance) +
          math.cos(latitude) * math.sin(angularDistance) * math.cos(heading),
    );
    final projectedLongitude =
        longitude +
        math.atan2(
          math.sin(heading) * math.sin(angularDistance) * math.cos(latitude),
          math.cos(angularDistance) -
              math.sin(latitude) * math.sin(projectedLatitude),
        );

    return NavigationCoordinate(
      latitude: _radiansToDegrees(projectedLatitude),
      longitude: _normalizeLongitude(_radiansToDegrees(projectedLongitude)),
    );
  }

  static double _safeSpeed(double? value) {
    if (value == null || !value.isFinite || value < 0) {
      return 0;
    }
    return value.clamp(0.0, _maximumProfileSpeedMetersPerSecond);
  }

  static double _lerp(double start, double end, double progress) {
    return start + (end - start) * progress;
  }

  static double _normalizeHeading(double heading) {
    return ((heading % 360) + 360) % 360;
  }

  static double _normalizeLongitude(double longitude) {
    return ((longitude + 540) % 360) - 180;
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  static double _radiansToDegrees(double radians) => radians * 180 / math.pi;
}
