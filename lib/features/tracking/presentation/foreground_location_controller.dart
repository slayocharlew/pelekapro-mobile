import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';
import 'package:pelekapro_mobile/features/tracking/domain/device_location_source.dart';

enum ForegroundLocationStatus {
  idle,
  requestingPermission,
  waitingForFix,
  syncing,
  tracking,
  paused,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  throttled,
  temporarilyUnavailable,
  trackingRejected,
}

class ForegroundLocationController extends ChangeNotifier {
  ForegroundLocationController({
    required this._repository,
    required this._source,
    required int deliveryId,
    required this._onUnauthorized,
    this._onTrackingRejected,
    this._onConnectionRestored,
    DateTime Function()? now,
    this.minimumSubmissionInterval = const Duration(seconds: 5),
    this.rateLimitBackoff = const Duration(minutes: 1),
  }) : _deliveryId = deliveryId,
       _now = now ?? DateTime.now,
       assert(deliveryId > 0),
       assert(minimumSubmissionInterval >= Duration.zero),
       assert(rateLimitBackoff > Duration.zero);

  final DeliveryRepository _repository;
  final DeviceLocationSource _source;
  final int _deliveryId;
  final VoidCallback _onUnauthorized;
  final FutureOr<void> Function()? _onTrackingRejected;
  final FutureOr<void> Function()? _onConnectionRestored;
  final DateTime Function() _now;
  final Duration minimumSubmissionInterval;
  final Duration rateLimitBackoff;

  ForegroundLocationStatus _status = ForegroundLocationStatus.idle;
  StreamSubscription<DeliveryLocationSample>? _subscription;
  DeliveryLocationSample? _pendingSample;
  RecordedDeliveryLocation? _lastRecordedLocation;
  DateTime? _lastAttemptAt;
  DateTime? _backoffUntil;
  double? _heading;
  String? _message;
  int _generation = 0;
  int? _sendingGeneration;
  bool _isStarting = false;
  bool _hadConnectionFailure = false;
  bool _didNotifyUnauthorized = false;
  bool _disposed = false;

  ForegroundLocationStatus get status => _status;
  RecordedDeliveryLocation? get lastRecordedLocation => _lastRecordedLocation;
  double? get heading => _heading;
  String? get message => _message;
  bool get hasActiveStream => _subscription != null;

  Future<void> start() async {
    if (_disposed || _isStarting || _subscription != null) {
      return;
    }

    final generation = ++_generation;
    _isStarting = true;
    _setStatus(ForegroundLocationStatus.requestingPermission);

    try {
      final access = await _source.ensureAccess();
      if (!_isCurrent(generation)) {
        return;
      }

      switch (access) {
        case DeviceLocationAccess.granted:
          _setStatus(ForegroundLocationStatus.waitingForFix);
          _subscription = _source.watch().listen(
            (sample) => _receive(sample, generation),
            onError: (Object error, StackTrace stackTrace) {
              _handleStreamError(generation);
            },
            onDone: () => _handleStreamError(generation),
            cancelOnError: false,
          );
        case DeviceLocationAccess.serviceDisabled:
          _setStatus(ForegroundLocationStatus.serviceDisabled);
        case DeviceLocationAccess.denied:
          _setStatus(ForegroundLocationStatus.permissionDenied);
        case DeviceLocationAccess.deniedForever:
          _setStatus(ForegroundLocationStatus.permissionDeniedForever);
      }
    } on Object {
      if (_isCurrent(generation)) {
        _setStatus(
          ForegroundLocationStatus.temporarilyUnavailable,
          'Location could not be started. Try again.',
        );
      }
    } finally {
      if (generation == _generation) {
        _isStarting = false;
      }
    }
  }

  Future<void> pause() {
    return _cancelTracking(nextStatus: ForegroundLocationStatus.paused);
  }

  Future<bool> openAppSettings() => _source.openAppSettings();

  Future<bool> openLocationSettings() => _source.openLocationSettings();

  void _receive(DeliveryLocationSample sample, int generation) {
    if (!_isCurrent(generation) || _subscription == null) {
      return;
    }

    if (sample.heading case final heading?) {
      _heading = heading;
    }
    _pendingSample = sample;
    unawaited(_drain(generation));
  }

  Future<void> _drain(int generation) async {
    if (!_isCurrent(generation) ||
        _subscription == null ||
        _sendingGeneration != null) {
      return;
    }

    final sample = _pendingSample;
    if (sample == null) {
      return;
    }

    final currentTime = _now().toUtc();
    final backoffUntil = _backoffUntil;
    if (backoffUntil != null && currentTime.isBefore(backoffUntil)) {
      _pendingSample = null;
      return;
    }

    final lastAttemptAt = _lastAttemptAt;
    if (lastAttemptAt != null &&
        currentTime.difference(lastAttemptAt) < minimumSubmissionInterval) {
      _pendingSample = null;
      return;
    }

    _pendingSample = null;
    _lastAttemptAt = currentTime;
    _sendingGeneration = generation;
    _setStatus(ForegroundLocationStatus.syncing);

    try {
      final recorded = await _repository.submitLocation(_deliveryId, sample);
      if (!_isCurrent(generation)) {
        return;
      }

      final connectionWasUnavailable = _hadConnectionFailure;
      _hadConnectionFailure = false;
      _backoffUntil = null;
      _lastRecordedLocation = recorded;
      if (recorded.heading case final heading?) {
        _heading = heading;
      }
      _setStatus(ForegroundLocationStatus.tracking);

      if (connectionWasUnavailable && _onConnectionRestored != null) {
        unawaited(Future<void>.sync(_onConnectionRestored));
      }
    } on DeliveryFailure catch (failure) {
      if (failure.isUnauthorized) {
        await _handleUnauthorized();
      } else if (_isCurrent(generation) &&
          (failure.statusCode == 403 ||
              failure.statusCode == 404 ||
              failure.statusCode == 409)) {
        await _cancelTracking(
          nextStatus: ForegroundLocationStatus.trackingRejected,
          message: 'Live tracking is no longer active for this delivery.',
        );
        if (_onTrackingRejected != null) {
          unawaited(Future<void>.sync(_onTrackingRejected));
        }
      } else if (_isCurrent(generation) && failure.statusCode == 429) {
        _backoffUntil = currentTime.add(rateLimitBackoff);
        _setStatus(
          ForegroundLocationStatus.throttled,
          'Location sync is paused briefly and will retry automatically.',
        );
      } else if (_isCurrent(generation)) {
        _hadConnectionFailure = true;
        _setStatus(
          ForegroundLocationStatus.temporarilyUnavailable,
          'Location sync was interrupted. PelekaPro will keep trying.',
        );
      }
    } on Object {
      if (_isCurrent(generation)) {
        _hadConnectionFailure = true;
        _setStatus(
          ForegroundLocationStatus.temporarilyUnavailable,
          'Location sync was interrupted. PelekaPro will keep trying.',
        );
      }
    } finally {
      if (_sendingGeneration == generation) {
        _sendingGeneration = null;
      }
      final currentGeneration = _generation;
      if (_pendingSample != null &&
          _subscription != null &&
          _isCurrent(currentGeneration)) {
        unawaited(_drain(currentGeneration));
      }
    }
  }

  void _handleStreamError(int generation) {
    if (!_isCurrent(generation)) {
      return;
    }
    unawaited(
      _cancelTracking(
        nextStatus: ForegroundLocationStatus.temporarilyUnavailable,
        message: 'Location signal is unavailable. Check device location.',
      ),
    );
  }

  Future<void> _handleUnauthorized() async {
    await _cancelTracking(nextStatus: ForegroundLocationStatus.paused);
    if (_didNotifyUnauthorized || _disposed) {
      return;
    }
    _didNotifyUnauthorized = true;
    _onUnauthorized();
  }

  Future<void> _cancelTracking({
    required ForegroundLocationStatus nextStatus,
    String? message,
  }) {
    if (_disposed) {
      return Future<void>.value();
    }

    _generation += 1;
    _isStarting = false;
    _pendingSample = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _setStatus(nextStatus, message);
    return Future<void>.value();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _setStatus(ForegroundLocationStatus value, [String? message]) {
    if (_disposed) {
      return;
    }
    _status = value;
    _message = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
