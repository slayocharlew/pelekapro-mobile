import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pelekapro_mobile/features/navigation/data/osrm_navigation_route_service.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_failure.dart';

void main() {
  group('OsrmNavigationRouteService', () {
    test('requests and parses real road geometry and next guidance', () async {
      late http.Request capturedRequest;
      final service = OsrmNavigationRouteService(
        baseUri: Uri.parse('https://routing.pelekapro.example'),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(jsonEncode(_routeResponse), 200);
        }),
      );

      final route = await service.route(
        origin: const NavigationCoordinate(
          latitude: -6.7924,
          longitude: 39.2083,
        ),
        destination: const NavigationCoordinate(
          latitude: -6.769,
          longitude: 39.234,
        ),
      );

      expect(capturedRequest.method, 'GET');
      expect(
        capturedRequest.url.path,
        '/route/v1/driving/39.2083000,-6.7924000;39.2340000,-6.7690000',
      );
      expect(capturedRequest.url.queryParameters['steps'], 'true');
      expect(capturedRequest.url.queryParameters['geometries'], 'geojson');
      expect(capturedRequest.url.queryParameters['overview'], 'full');
      expect(
        capturedRequest.headers['user-agent'],
        'PelekaProMobile/1.0 (tz.co.pelekapro.mobile)',
      );
      expect(route.geometry, hasLength(3));
      expect(route.geometry.first.latitude, -6.7924);
      expect(route.geometry.last.longitude, 39.234);
      expect(route.distanceMeters, 3200);
      expect(route.durationSeconds, 360);
      expect(route.guidance.instruction, 'Turn right');
      expect(route.guidance.roadName, 'Mwai Kibaki Road');
      expect(route.guidance.distanceMeters, 180);
      expect(route.guidance.maneuver, NavigationManeuver.right);
    });

    test('reports that no road route was found without inventing one', () {
      final service = OsrmNavigationRouteService(
        baseUri: Uri.parse('https://routing.pelekapro.example'),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'code': 'NoRoute', 'routes': <Object?>[]}),
            200,
          ),
        ),
      );

      expect(
        service.route(
          origin: const NavigationCoordinate(
            latitude: -6.7924,
            longitude: 39.2083,
          ),
          destination: const NavigationCoordinate(
            latitude: -6.769,
            longitude: 39.234,
          ),
        ),
        throwsA(
          isA<NavigationRouteFailure>().having(
            (failure) => failure.message,
            'message',
            'No road route was found to this drop-off.',
          ),
        ),
      );
    });
  });
}

const _routeResponse = {
  'code': 'Ok',
  'routes': [
    {
      'distance': 3200.0,
      'duration': 360.0,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [39.2083, -6.7924],
          [39.2200, -6.7800],
          [39.2340, -6.7690],
        ],
      },
      'legs': [
        {
          'steps': [
            {
              'distance': 180.0,
              'name': 'Samora Avenue',
              'maneuver': {'type': 'depart', 'modifier': 'straight'},
            },
            {
              'distance': 2500.0,
              'name': 'Mwai Kibaki Road',
              'maneuver': {'type': 'turn', 'modifier': 'right'},
            },
            {
              'distance': 0.0,
              'name': '',
              'maneuver': {'type': 'arrive', 'modifier': 'straight'},
            },
          ],
        },
      ],
    },
  ],
};
