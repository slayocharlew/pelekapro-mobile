import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_pose_stabilizer.dart';

void main() {
  const origin = NavigationCoordinate(latitude: -6.7924, longitude: 39.2083);

  group('NavigationPoseStabilizer', () {
    test('freezes marker position and heading while stationary', () {
      final stabilizer = NavigationPoseStabilizer();

      final first = stabilizer.update(
        position: origin,
        heading: 245,
        speedMetersPerSecond: 0,
        accuracyMeters: 8,
      );
      final jittered = stabilizer.update(
        position: const NavigationCoordinate(
          latitude: -6.79239,
          longitude: 39.20831,
        ),
        heading: 35,
        speedMetersPerSecond: 0.1,
        accuracyMeters: 8,
      );

      expect(first.heading, 0);
      expect(jittered.heading, 0);
      expect(jittered.position, origin);
      expect(jittered.isMoving, isFalse);
    });

    test('locks onto travel direction and retains it after stopping', () {
      final stabilizer = NavigationPoseStabilizer();
      stabilizer.update(
        position: origin,
        heading: 270,
        speedMetersPerSecond: 0,
        accuracyMeters: 5,
      );

      final moving = stabilizer.update(
        position: const NavigationCoordinate(
          latitude: -6.7924,
          longitude: 39.2084,
        ),
        heading: 90,
        speedMetersPerSecond: 5,
        accuracyMeters: 5,
      );
      final stopped = stabilizer.update(
        position: const NavigationCoordinate(
          latitude: -6.7924,
          longitude: 39.208405,
        ),
        heading: 280,
        speedMetersPerSecond: 0,
        accuracyMeters: 5,
      );

      expect(moving.heading, closeTo(90, 1));
      expect(stopped.heading, moving.heading);
      expect(stopped.isMoving, isFalse);
    });

    test(
      'smooths a sharp heading change without making turns unresponsive',
      () {
        final stabilizer = NavigationPoseStabilizer();
        stabilizer.update(
          position: origin,
          heading: 0,
          speedMetersPerSecond: 6,
          accuracyMeters: 4,
        );

        final turned = stabilizer.update(
          position: const NavigationCoordinate(
            latitude: -6.7924,
            longitude: 39.2084,
          ),
          heading: 90,
          speedMetersPerSecond: 8,
          accuracyMeters: 4,
        );

        expect(turned.heading, greaterThan(45));
        expect(turned.heading, lessThanOrEqualTo(65));
        expect(turned.heading, isNot(90));
      },
    );

    test('follows a real right-angle turn within two location updates', () {
      final stabilizer = NavigationPoseStabilizer();
      stabilizer.update(
        position: origin,
        heading: 90,
        speedMetersPerSecond: 5,
        accuracyMeters: 4,
      );
      stabilizer.update(
        position: const NavigationCoordinate(
          latitude: -6.7924,
          longitude: 39.2084,
        ),
        heading: 90,
        speedMetersPerSecond: 5,
        accuracyMeters: 4,
      );

      stabilizer.update(
        position: const NavigationCoordinate(
          latitude: -6.7923,
          longitude: 39.2084,
        ),
        heading: 0,
        speedMetersPerSecond: 4,
        accuracyMeters: 4,
      );
      final afterSecondTurnFix = stabilizer.update(
        position: const NavigationCoordinate(
          latitude: -6.7922,
          longitude: 39.2084,
        ),
        heading: 0,
        speedMetersPerSecond: 4,
        accuracyMeters: 4,
      );

      expect(afterSecondTurnFix.heading, lessThan(18));
    });

    test('accepts a real stationary position correction outside accuracy', () {
      final stabilizer = NavigationPoseStabilizer();
      stabilizer.update(
        position: origin,
        heading: 0,
        speedMetersPerSecond: 0,
        accuracyMeters: 4,
      );
      const corrected = NavigationCoordinate(
        latitude: -6.7923,
        longitude: 39.2084,
      );

      final pose = stabilizer.update(
        position: corrected,
        heading: 180,
        speedMetersPerSecond: 0,
        accuracyMeters: 4,
      );

      expect(pose.position, corrected);
      expect(pose.heading, 0);
    });

    test('stops rotating despite a large GPS correction after movement', () {
      final stabilizer = NavigationPoseStabilizer();
      stabilizer.update(
        position: origin,
        heading: 90,
        speedMetersPerSecond: 5,
        accuracyMeters: 4,
      );
      final moving = stabilizer.update(
        position: const NavigationCoordinate(
          latitude: -6.7924,
          longitude: 39.2084,
        ),
        heading: 90,
        speedMetersPerSecond: 5,
        accuracyMeters: 4,
      );

      final stopped = stabilizer.update(
        position: const NavigationCoordinate(
          latitude: -6.7923,
          longitude: 39.2085,
        ),
        heading: 245,
        speedMetersPerSecond: 0,
        accuracyMeters: 4,
      );

      expect(stopped.isMoving, isFalse);
      expect(stopped.heading, moving.heading);
    });
  });
}
