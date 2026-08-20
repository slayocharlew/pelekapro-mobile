import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_failure.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_service.dart';

class OsrmNavigationRouteService implements NavigationRouteService {
  OsrmNavigationRouteService({
    required Uri baseUri,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 12),
  }) : _baseUri = baseUri,
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       assert({'http', 'https'}.contains(baseUri.scheme)),
       assert(baseUri.host.isNotEmpty),
       assert(requestTimeout > Duration.zero);

  final Uri _baseUri;
  final http.Client _client;
  final bool _ownsClient;
  final Duration requestTimeout;

  @override
  bool get isConfigured => true;

  @override
  Future<NavigationRoute> route({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
  }) async {
    if (!origin.isValid || !destination.isValid) {
      throw const NavigationRouteFailure('Route coordinates are not valid.');
    }

    late final http.Response response;
    try {
      response = await _client
          .get(
            _routeUri(origin, destination),
            headers: const {
              HttpHeaders.acceptHeader: 'application/json',
              HttpHeaders.userAgentHeader:
                  'PelekaProMobile/1.0 (tz.co.pelekapro.mobile)',
            },
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const NavigationRouteFailure(
        'Route guidance timed out. Showing your real map position only.',
      );
    } on IOException {
      throw const NavigationRouteFailure(
        'Route guidance is temporarily unavailable.',
      );
    } on http.ClientException {
      throw const NavigationRouteFailure(
        'Route guidance is temporarily unavailable.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const NavigationRouteFailure(
        'Route guidance is temporarily unavailable.',
      );
    }

    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Expected an OSRM object.');
      }
      if (payload['code'] != 'Ok') {
        final message = payload['code'] == 'NoRoute'
            ? 'No road route was found to this drop-off.'
            : 'Route guidance is temporarily unavailable.';
        throw NavigationRouteFailure(message);
      }
      return _parseRoute(payload);
    } on NavigationRouteFailure {
      rethrow;
    } on FormatException {
      throw const NavigationRouteFailure(
        'The routing service returned an invalid route.',
      );
    }
  }

  Uri _routeUri(NavigationCoordinate origin, NavigationCoordinate destination) {
    final base = _baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
    final coordinates = [
      '${origin.longitude.toStringAsFixed(7)},${origin.latitude.toStringAsFixed(7)}',
      '${destination.longitude.toStringAsFixed(7)},${destination.latitude.toStringAsFixed(7)}',
    ].join(';');

    return Uri.parse('$base/route/v1/driving/$coordinates').replace(
      queryParameters: const {
        'alternatives': 'false',
        'steps': 'true',
        'geometries': 'geojson',
        'overview': 'full',
      },
    );
  }

  NavigationRoute _parseRoute(Map<String, dynamic> payload) {
    final routes = _list(payload['routes'], 'routes');
    if (routes.isEmpty) {
      throw const FormatException('Missing route.');
    }
    final route = _map(routes.first, 'routes[0]');
    final geometry = _map(route['geometry'], 'geometry');
    final coordinates = _list(geometry['coordinates'], 'coordinates')
        .map((value) {
          final pair = _list(value, 'coordinates[]');
          if (pair.length < 2) {
            throw const FormatException('Invalid route coordinate.');
          }
          final longitude = _number(pair[0], 'longitude');
          final latitude = _number(pair[1], 'latitude');
          final coordinate = NavigationCoordinate(
            latitude: latitude,
            longitude: longitude,
          );
          if (!coordinate.isValid) {
            throw const FormatException('Out-of-range route coordinate.');
          }
          return coordinate;
        })
        .toList(growable: false);
    if (coordinates.length < 2) {
      throw const FormatException('Route geometry is incomplete.');
    }

    final distance = _nonNegativeNumber(route['distance'], 'distance');
    final duration = _nonNegativeNumber(route['duration'], 'duration');
    final steps = <Map<String, dynamic>>[];
    for (final legValue in _list(route['legs'], 'legs')) {
      final leg = _map(legValue, 'legs[]');
      for (final stepValue in _list(leg['steps'], 'steps')) {
        steps.add(_map(stepValue, 'steps[]'));
      }
    }

    return NavigationRoute(
      geometry: coordinates,
      distanceMeters: distance,
      durationSeconds: duration,
      guidance: _guidance(steps, fallbackDistance: distance),
    );
  }

  NavigationGuidance _guidance(
    List<Map<String, dynamic>> steps, {
    required double fallbackDistance,
  }) {
    if (steps.isEmpty) {
      return NavigationGuidance(
        instruction: 'Continue to the drop-off',
        roadName: 'Route in progress',
        distanceMeters: fallbackDistance,
        maneuver: NavigationManeuver.straight,
      );
    }

    final current = steps.first;
    final target = steps.length > 1 ? steps[1] : current;
    final maneuver = _map(target['maneuver'], 'maneuver');
    final type = _optionalString(maneuver['type']) ?? 'continue';
    final modifier = _optionalString(maneuver['modifier']) ?? 'straight';
    final exit = maneuver['exit'] is num
        ? (maneuver['exit'] as num).toInt()
        : null;
    final targetName = _optionalString(target['name']);
    final currentName = _optionalString(current['name']);

    return NavigationGuidance(
      instruction: _instruction(type, modifier, exit),
      roadName: targetName ?? currentName ?? 'Unnamed road',
      distanceMeters: _nonNegativeNumber(current['distance'], 'step distance'),
      maneuver: _maneuver(type, modifier),
    );
  }

  String _instruction(String type, String modifier, int? exit) {
    final direction = _directionLabel(modifier);
    return switch (type) {
      'depart' =>
        direction == 'straight' ? 'Start on this road' : 'Head $direction',
      'arrive' => 'Arrive at the drop-off',
      'turn' || 'end of road' =>
        direction == 'straight' ? 'Continue straight' : 'Turn $direction',
      'continue' || 'new name' =>
        direction == 'straight' ? 'Continue straight' : 'Continue $direction',
      'merge' => direction == 'straight' ? 'Merge ahead' : 'Merge $direction',
      'fork' => direction == 'straight' ? 'Keep straight' : 'Keep $direction',
      'on ramp' =>
        direction == 'straight' ? 'Take the ramp' : 'Take the ramp $direction',
      'off ramp' =>
        direction == 'straight' ? 'Take the exit' : 'Take the exit $direction',
      'roundabout' || 'rotary' || 'roundabout turn' =>
        exit == null
            ? 'Enter the roundabout'
            : 'Take exit $exit at the roundabout',
      _ => direction == 'straight' ? 'Continue ahead' : 'Continue $direction',
    };
  }

  NavigationManeuver _maneuver(String type, String modifier) {
    if (type == 'arrive') {
      return NavigationManeuver.arrive;
    }
    if (type == 'depart') {
      return NavigationManeuver.depart;
    }
    if (type == 'merge' || type == 'on ramp' || type == 'off ramp') {
      return NavigationManeuver.merge;
    }
    if (type == 'fork') {
      return NavigationManeuver.fork;
    }
    if (type == 'roundabout' || type == 'rotary' || type == 'roundabout turn') {
      return NavigationManeuver.roundabout;
    }
    return switch (modifier) {
      'uturn' => NavigationManeuver.uTurn,
      'sharp left' => NavigationManeuver.sharpLeft,
      'left' => NavigationManeuver.left,
      'slight left' => NavigationManeuver.slightLeft,
      'sharp right' => NavigationManeuver.sharpRight,
      'right' => NavigationManeuver.right,
      'slight right' => NavigationManeuver.slightRight,
      _ => NavigationManeuver.straight,
    };
  }

  String _directionLabel(String modifier) {
    return switch (modifier) {
      'uturn' => 'around',
      'sharp left' => 'sharply left',
      'slight left' => 'slightly left',
      'sharp right' => 'sharply right',
      'slight right' => 'slightly right',
      'left' || 'right' => modifier,
      _ => 'straight',
    };
  }

  static Map<String, dynamic> _map(Object? value, String field) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw FormatException('Expected $field object.');
  }

  static List<Object?> _list(Object? value, String field) {
    if (value is List<Object?>) {
      return value;
    }
    throw FormatException('Expected $field list.');
  }

  static double _number(Object? value, String field) {
    final number = switch (value) {
      num candidate => candidate.toDouble(),
      String candidate => double.tryParse(candidate),
      _ => null,
    };
    if (number == null || !number.isFinite) {
      throw FormatException('Expected numeric $field.');
    }
    return number;
  }

  static double _nonNegativeNumber(Object? value, String field) {
    final number = _number(value, field);
    if (number < 0) {
      throw FormatException('Expected non-negative $field.');
    }
    return number;
  }

  static String? _optionalString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
