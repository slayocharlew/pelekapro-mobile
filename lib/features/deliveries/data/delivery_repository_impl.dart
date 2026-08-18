import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/core/storage/token_storage.dart';
import 'package:pelekapro_mobile/features/deliveries/data/delivery_remote_data_source.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';

class DeliveryRepositoryImpl implements DeliveryRepository {
  DeliveryRepositoryImpl({
    required this.remoteDataSource,
    required this.tokenStorage,
    required this.now,
  });

  final DeliveryRemoteDataSource remoteDataSource;
  final TokenStorage tokenStorage;
  final DateTime Function() now;

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
    _validateDeliveryId(deliveryId);

    return _withAccessToken(
      (accessToken) => remoteDataSource.startDelivery(deliveryId, accessToken),
    );
  }

  @override
  Future<RecordedDeliveryLocation> submitLocation(
    int deliveryId,
    DeliveryLocationSample sample,
  ) {
    _validateDeliveryId(deliveryId);

    return _withAccessToken(
      (accessToken) =>
          remoteDataSource.submitLocation(deliveryId, sample, accessToken),
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
  void close() => remoteDataSource.close();
}
