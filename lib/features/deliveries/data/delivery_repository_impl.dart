import 'package:firebase_auth/firebase_auth.dart';
import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/core/storage/token_storage.dart';
import 'package:pelekapro_mobile/features/deliveries/data/delivery_remote_data_source.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_completion_request.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';
import 'package:pelekapro_mobile/features/tracking/data/firebase_delivery_location_data_source.dart';
import 'package:pelekapro_mobile/features/tracking/domain/firebase_tracking_credential.dart';

class DeliveryRepositoryImpl
    implements DeliveryRepository, LocationAwareDeliveryStarter {
  DeliveryRepositoryImpl({
    required this.remoteDataSource,
    required this.tokenStorage,
    required this.now,
    this.firebaseLocations,
  });

  final DeliveryRemoteDataSource remoteDataSource;
  final TokenStorage tokenStorage;
  final DateTime Function() now;
  final FirebaseDeliveryLocationDataSource? firebaseLocations;
  final Map<int, FirebaseTrackingCredential> _trackingCredentials = {};
  final Set<int> _legacyLocationDeliveries = {};

  @override
  Future<List<DriverDelivery>> fetchAssignedDeliveries() {
    return _withAccessToken(remoteDataSource.fetchAssignedDeliveries);
  }

  @override
  Future<DriverDeliveryDetails> fetchDeliveryDetails(int deliveryId) {
    _validateDeliveryId(deliveryId);

    return _withAccessToken(
      (accessToken) =>
          remoteDataSource.fetchDeliveryDetails(deliveryId, accessToken),
    );
  }

  @override
  Future<DriverDelivery> startDelivery(int deliveryId) {
    return _startDelivery(deliveryId, null);
  }

  @override
  Future<DriverDelivery> startDeliveryAtLocation(
    int deliveryId,
    DeliveryLocationSample startLocation,
  ) {
    return _startDelivery(deliveryId, startLocation);
  }

  Future<DriverDelivery> _startDelivery(
    int deliveryId,
    DeliveryLocationSample? startLocation,
  ) {
    _validateDeliveryId(deliveryId);

    return _withAccessToken(
      (accessToken) => remoteDataSource.startDelivery(
        deliveryId,
        accessToken,
        startLocation,
      ),
    );
  }

  @override
  Future<RecordedDeliveryLocation> submitLocation(
    int deliveryId,
    DeliveryLocationSample sample,
  ) {
    _validateDeliveryId(deliveryId);

    final firebase = firebaseLocations;
    if (firebase == null || _legacyLocationDeliveries.contains(deliveryId)) {
      return _withAccessToken(
        (accessToken) =>
            remoteDataSource.submitLocation(deliveryId, sample, accessToken),
      );
    }

    return _submitFirebaseLocation(deliveryId, sample, firebase);
  }

  Future<RecordedDeliveryLocation> _submitFirebaseLocation(
    int deliveryId,
    DeliveryLocationSample sample,
    FirebaseDeliveryLocationDataSource firebase,
  ) async {
    try {
      final cachedCredential = _trackingCredentials[deliveryId];
      late final FirebaseTrackingCredential credential;
      if (cachedCredential == null || cachedCredential.needsRefresh(now())) {
        credential = await _withAccessToken(
          (accessToken) =>
              remoteDataSource.fetchTrackingCredential(deliveryId, accessToken),
        );
        _trackingCredentials[deliveryId] = credential;
        await firebase.authenticate(credential);
      } else {
        credential = cachedCredential;
      }

      await firebase.submit(credential, sample);
      return RecordedDeliveryLocation(
        latitude: sample.latitude,
        longitude: sample.longitude,
        accuracy: sample.accuracy,
        speed: sample.speed,
        heading: sample.heading,
        recordedAt: sample.recordedAt,
      );
    } on DeliveryFailure catch (failure) {
      if (failure.statusCode == 409 &&
          failure.message == 'Firebase tracking is not enabled.') {
        _legacyLocationDeliveries.add(deliveryId);
        return submitLocation(deliveryId, sample);
      }
      rethrow;
    } on FirebaseAuthException catch (error) {
      _trackingCredentials.remove(deliveryId);
      throw DeliveryFailure(
        message: 'Secure live tracking could not be authorized. Try again.',
        statusCode: error.code == 'network-request-failed' ? null : 409,
      );
    } on FirebaseException {
      throw const DeliveryFailure(
        message: 'Live location sync was interrupted. PelekaPro will retry.',
      );
    }
  }

  @override
  Future<DriverDelivery> completeDelivery(
    int deliveryId,
    DeliveryCompletionRequest request,
  ) {
    _validateDeliveryId(deliveryId);

    return _withAccessToken(
      (accessToken) =>
          remoteDataSource.completeDelivery(deliveryId, request, accessToken),
    );
  }

  void _validateDeliveryId(int deliveryId) {
    if (deliveryId <= 0) {
      throw const DeliveryFailure(
        message: 'The selected delivery could not be identified.',
      );
    }
  }

  Future<T> _withAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) async {
    final token = await _readToken();

    if (token == null) {
      throw const DeliveryFailure(
        message: 'Your session has expired. Sign in again.',
        statusCode: 401,
      );
    }

    final expiresAt = token.expiresAt;
    if (expiresAt != null && !expiresAt.toUtc().isAfter(now().toUtc())) {
      await _clearToken();
      throw const DeliveryFailure(
        message: 'Your session has expired. Sign in again.',
        statusCode: 401,
      );
    }

    try {
      return await request(token.accessToken);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearToken();
        throw const DeliveryFailure(
          message: 'Your session has expired. Sign in again.',
          statusCode: 401,
        );
      }

      throw DeliveryFailure(
        message: error.message,
        statusCode: error.statusCode,
        fieldErrors: error.fieldErrors,
      );
    }
  }

  Future<StoredAuthToken?> _readToken() async {
    try {
      return await tokenStorage.read();
    } on Object {
      throw const DeliveryFailure(
        message:
            'The secure session could not be read. Restart the app and try again.',
      );
    }
  }

  Future<void> _clearToken() async {
    try {
      await tokenStorage.clear();
    } on Object {
      throw const DeliveryFailure(
        message:
            'The expired session could not be removed securely. Restart the app.',
        statusCode: 401,
      );
    }
  }

  @override
  void close() {
    firebaseLocations?.signOut();
    remoteDataSource.close();
  }
}
