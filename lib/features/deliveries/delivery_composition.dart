import 'package:pelekapro_mobile/core/config/app_config.dart';
import 'package:pelekapro_mobile/core/network/api_client.dart';
import 'package:pelekapro_mobile/core/storage/secure_token_storage.dart';
import 'package:pelekapro_mobile/features/deliveries/data/delivery_remote_data_source.dart';
import 'package:pelekapro_mobile/features/deliveries/data/delivery_repository_impl.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';

abstract final class DeliveryComposition {
  static DeliveryRepository createRepository() {
    final baseUri = AppConfig.apiBaseUri;

    if (baseUri == null) {
      return const _UnconfiguredDeliveryRepository();
    }

    final apiClient = ApiClient(baseUri: baseUri);
    return DeliveryRepositoryImpl(
      remoteDataSource: DeliveryRemoteDataSource(apiClient),
      tokenStorage: SecureTokenStorage(),
      now: DateTime.now,
    );
  }
}

class _UnconfiguredDeliveryRepository implements DeliveryRepository {
  const _UnconfiguredDeliveryRepository();

  @override
  Future<List<DriverDelivery>> fetchAssignedDeliveries() {
    throw const DeliveryFailure(
      message:
          'The API connection is not configured. Start the app with API_BASE_URL set for your PelekaPro server.',
    );
  }

  @override
  Future<DriverDeliveryDetails> fetchDeliveryDetails(int deliveryId) {
    throw const DeliveryFailure(
      message:
          'The API connection is not configured. Start the app with API_BASE_URL set for your PelekaPro server.',
    );
  }

  @override
  Future<DriverDelivery> startDelivery(int deliveryId) {
    throw const DeliveryFailure(
      message:
          'The API connection is not configured. Start the app with API_BASE_URL set for your PelekaPro server.',
    );
  }

  @override
  void close() {}
}
