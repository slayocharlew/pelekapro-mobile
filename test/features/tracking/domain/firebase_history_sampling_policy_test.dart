import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/tracking/domain/firebase_history_sampling_policy.dart';

void main() {
  const policy = FirebaseHistorySamplingPolicy();
  final startedAt = DateTime.utc(2026, 8, 26, 10);

  DeliveryLocationSample sample({
    required double latitude,
    required double longitude,
    required Duration afterStart,
  }) {
    return DeliveryLocationSample(
      latitude: latitude,
      longitude: longitude,
      recordedAt: startedAt.add(afterStart),
    );
  }

  test('retains the first sample', () {
    final current = sample(
      latitude: -6.7924,
      longitude: 39.2083,
      afterStart: Duration.zero,
    );

    expect(policy.shouldRetain(previous: null, current: current), isTrue);
  });

  test('skips a nearby sample before twenty seconds', () {
    final previous = sample(
      latitude: -6.7924,
      longitude: 39.2083,
      afterStart: Duration.zero,
    );
    final current = sample(
      latitude: -6.79241,
      longitude: 39.20831,
      afterStart: const Duration(seconds: 5),
    );

    expect(policy.shouldRetain(previous: previous, current: current), isFalse);
  });

  test('retains a nearby sample after twenty seconds', () {
    final previous = sample(
      latitude: -6.7924,
      longitude: 39.2083,
      afterStart: Duration.zero,
    );
    final current = sample(
      latitude: -6.79241,
      longitude: 39.20831,
      afterStart: const Duration(seconds: 20),
    );

    expect(policy.shouldRetain(previous: previous, current: current), isTrue);
  });

  test('retains a point after meaningful movement before twenty seconds', () {
    final previous = sample(
      latitude: -6.7924,
      longitude: 39.2083,
      afterStart: Duration.zero,
    );
    final current = sample(
      latitude: -6.7918,
      longitude: 39.2083,
      afterStart: const Duration(seconds: 5),
    );

    expect(policy.distanceMetres(previous, current), greaterThan(50));
    expect(policy.shouldRetain(previous: previous, current: current), isTrue);
  });

  test('a delayed nearby point does not replace the sampling baseline', () {
    final previous = sample(
      latitude: -6.7924,
      longitude: 39.2083,
      afterStart: const Duration(seconds: 20),
    );
    final delayed = sample(
      latitude: -6.79241,
      longitude: 39.20831,
      afterStart: const Duration(seconds: 10),
    );

    expect(policy.shouldRetain(previous: previous, current: delayed), isFalse);
  });
}
