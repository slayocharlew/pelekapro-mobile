import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_failure.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_service.dart';

enum NavigationRouteStatus { idle, loading, ready, unavailable }

class NavigationRouteController extends ChangeNotifier {
  NavigationRouteController(
    this._service, {
    DateTime Function()? now,
    this.minimumMovementMeters = 35,
    this.minimumRefreshInterval = const Duration(seconds: 20),
    this.stationaryRefreshInterval = const Duration(minutes: 1),
  }) : _now = now ?? DateTime.now,
       assert(minimumMovementMeters >= 0),
       assert(minimumRefreshInterval >= Duration.zero),
       assert(stationaryRefreshInterval >= minimumRefreshInterval);

  final NavigationRouteService _service;
  final DateTime Function() _now;
  final double minimumMovementMeters;
  final Duration minimumRefreshInterval;
  final Duration stationaryRefreshInterval;

  NavigationRouteStatus _status = NavigationRouteStatus.idle;
  NavigationRoute? _route;
  String? _message;
  NavigationCoordinate? _lastRequestedOrigin;
  NavigationCoordinate? _lastDestination;
  DateTime? _lastRequestedAt;
  NavigationCoordinate? _pendingOrigin;
  NavigationCoordinate? _pendingDestination;
  int _generation = 0;
  bool _requestInFlight = false;
  bool _disposed = false;

  NavigationRouteStatus get status => _status;
  NavigationRoute? get route => _route;
  String? get message => _message;
  bool get isRefreshing => _requestInFlight && _route != null;
  bool get isConfigured => _service.isConfigured;

  Future<void> update({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    bool force = false,
  }) async {
    if (_disposed || !origin.isValid || !destination.isValid) {
      return;
    }

    if (!_service.isConfigured) {
      _route = null;
      _status = NavigationRouteStatus.unavailable;
      _message =
          'Road guidance is not configured. Showing real map positions only.';
      notifyListeners();
      return;
    }

    if (_requestInFlight) {
      _pendingOrigin = origin;
      _pendingDestination = destination;
      return;
    }

    if (!force && !_shouldRefresh(origin, destination)) {
      return;
    }

    final destinationChanged =
        _lastDestination != null && _lastDestination != destination;
    if (destinationChanged) {
      _route = null;
    }
    final generation = ++_generation;
    _requestInFlight = true;
    _lastRequestedOrigin = origin;
    _lastDestination = destination;
    _lastRequestedAt = _now().toUtc();
    _message = null;
    if (_route == null) {
      _status = NavigationRouteStatus.loading;
    }
    notifyListeners();

    try {
      final result = await _service.route(
        origin: origin,
        destination: destination,
      );
      if (!_isCurrent(generation)) {
        return;
      }
      if (_pendingDestination case final pending? when pending != destination) {
        return;
      }
      _route = result;
      _status = NavigationRouteStatus.ready;
      _message = null;
    } on NavigationRouteFailure catch (failure) {
      if (!_isCurrent(generation)) {
        return;
      }
      _message = failure.message;
      _status = _route == null
          ? NavigationRouteStatus.unavailable
          : NavigationRouteStatus.ready;
    } on Object {
      if (!_isCurrent(generation)) {
        return;
      }
      _message = 'Route guidance is temporarily unavailable.';
      _status = _route == null
          ? NavigationRouteStatus.unavailable
          : NavigationRouteStatus.ready;
    } finally {
      if (_isCurrent(generation)) {
        _requestInFlight = false;
        notifyListeners();
        final pendingOrigin = _pendingOrigin;
        final pendingDestination = _pendingDestination;
        _pendingOrigin = null;
        _pendingDestination = null;
        if (pendingOrigin != null && pendingDestination != null) {
          unawaited(
            update(origin: pendingOrigin, destination: pendingDestination),
          );
        }
      }
    }
  }

  Future<void> retry({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
  }) {
    return update(origin: origin, destination: destination, force: true);
  }

  bool _shouldRefresh(
    NavigationCoordinate origin,
    NavigationCoordinate destination,
  ) {
    final lastOrigin = _lastRequestedOrigin;
    final lastDestination = _lastDestination;
    final lastRequestedAt = _lastRequestedAt;
    if (_route == null ||
        lastOrigin == null ||
        lastDestination == null ||
        lastRequestedAt == null ||
        lastDestination != destination) {
      return true;
    }

    final elapsed = _now().toUtc().difference(lastRequestedAt);
    if (elapsed < minimumRefreshInterval) {
      return false;
    }

    final movedMeters = _distanceMeters(lastOrigin, origin);
    return movedMeters >= minimumMovementMeters ||
        elapsed >= stationaryRefreshInterval;
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
    final boundedHaversine = haversine.clamp(0.0, 1.0);
    return 2 *
        earthRadiusMeters *
        math.atan2(
          math.sqrt(boundedHaversine),
          math.sqrt(1 - boundedHaversine),
        );
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    super.dispose();
  }
}
