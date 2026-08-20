import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_failure.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_service.dart';
import 'package:pelekapro_mobile/features/navigation/presentation/navigation_route_controller.dart';

void main() {
  test('loads once then refreshes after meaningful driver movement', () async {
    var now = DateTime.utc(2026, 8, 20, 12);
    final service = _FakeRouteService(result: _route);
    final controller = NavigationRouteController(
      service,
      now: () => now,
      minimumRefreshInterval: const Duration(seconds: 20),
      stationaryRefreshInterval: const Duration(minutes: 1),
    );
    addTearDown(controller.dispose);
    const destination = NavigationCoordinate(
      latitude: -6.769,
      longitude: 39.234,
    );
    const origin = NavigationCoordinate(latitude: -6.7924, longitude: 39.2083);

    await controller.update(origin: origin, destination: destination);
    expect(controller.status, NavigationRouteStatus.ready);
    expect(controller.route, same(_route));
    expect(service.calls, 1);

    now = now.add(const Duration(seconds: 10));
    await controller.update(
      origin: const NavigationCoordinate(latitude: -6.7920, longitude: 39.2087),
      destination: destination,
    );
    expect(service.calls, 1);

    now = now.add(const Duration(seconds: 15));
    await controller.update(
      origin: const NavigationCoordinate(latitude: -6.7910, longitude: 39.2097),
      destination: destination,
    );
    expect(service.calls, 2);
  });

  test('never fabricates a route when routing is unavailable', () async {
    final service = _FakeRouteService(
      result: _route,
      failure: const NavigationRouteFailure('No route available.'),
    );
    final controller = NavigationRouteController(service);
    addTearDown(controller.dispose);

    await controller.update(
      origin: const NavigationCoordinate(latitude: -6.7924, longitude: 39.2083),
      destination: const NavigationCoordinate(
        latitude: -6.769,
        longitude: 39.234,
      ),
    );

    expect(controller.route, isNull);
    expect(controller.status, NavigationRouteStatus.unavailable);
    expect(controller.message, 'No route available.');
  });
}

final _route = NavigationRoute(
  geometry: const [
    NavigationCoordinate(latitude: -6.7924, longitude: 39.2083),
    NavigationCoordinate(latitude: -6.769, longitude: 39.234),
  ],
  distanceMeters: 3200,
  durationSeconds: 360,
  guidance: const NavigationGuidance(
    instruction: 'Turn right',
    roadName: 'Mwai Kibaki Road',
    distanceMeters: 180,
    maneuver: NavigationManeuver.right,
  ),
);

class _FakeRouteService implements NavigationRouteService {
  _FakeRouteService({required this.result, this.failure});

  final NavigationRoute result;
  final NavigationRouteFailure? failure;
  int calls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<NavigationRoute> route({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
  }) async {
    calls += 1;
    if (failure case final configuredFailure?) {
      throw configuredFailure;
    }
    return result;
  }

  @override
  void close() {}
}
