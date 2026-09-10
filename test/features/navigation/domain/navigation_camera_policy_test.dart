import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_camera_policy.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';

void main() {
  group('NavigationCameraPolicy', () {
    test('zooms out and looks farther ahead as motorcycle speed increases', () {
      final stopped = NavigationCameraPolicy.profileFor(0);
      final city = NavigationCameraPolicy.profileFor(8);
      final fast = NavigationCameraPolicy.profileFor(25);

      expect(stopped.zoom, greaterThan(city.zoom));
      expect(city.zoom, greaterThan(fast.zoom));
      expect(stopped.lookAheadMeters, lessThan(city.lookAheadMeters));
      expect(city.lookAheadMeters, lessThan(fast.lookAheadMeters));
      expect(stopped.tilt, lessThan(fast.tilt));
    });

    test('uses a safe stationary profile for invalid speed', () {
      final expected = NavigationCameraPolicy.profileFor(0);

      expect(NavigationCameraPolicy.profileFor(null).zoom, expected.zoom);
      expect(NavigationCameraPolicy.profileFor(-1).zoom, expected.zoom);
      expect(NavigationCameraPolicy.profileFor(double.nan).zoom, expected.zoom);
    });

    test('projects the camera target ahead of northbound travel', () {
      const origin = NavigationCoordinate(
        latitude: -6.7924,
        longitude: 39.2083,
      );

      final projected = NavigationCameraPolicy.lookAhead(
        origin: origin,
        headingDegrees: 0,
        distanceMeters: 80,
      );

      expect(projected.latitude, greaterThan(origin.latitude));
      expect(projected.longitude, closeTo(origin.longitude, 0.000001));
    });

    test('keeps the origin when look-ahead input is invalid', () {
      const origin = NavigationCoordinate(
        latitude: -6.7924,
        longitude: 39.2083,
      );

      expect(
        NavigationCameraPolicy.lookAhead(
          origin: origin,
          headingDegrees: double.nan,
          distanceMeters: 80,
        ),
        origin,
      );
      expect(
        NavigationCameraPolicy.lookAhead(
          origin: origin,
          headingDegrees: 90,
          distanceMeters: 0,
        ),
        origin,
      );
    });
  });
}
