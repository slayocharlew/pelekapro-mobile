import 'package:pelekapro_mobile/core/network/api_client.dart';
import 'package:pelekapro_mobile/core/network/api_exception.dart';
import 'package:pelekapro_mobile/features/deliveries/data/models/driver_delivery_details_mapper.dart';
import 'package:pelekapro_mobile/features/deliveries/data/models/driver_delivery_mapper.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';

class DeliveryRemoteDataSource {
  const DeliveryRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DriverDelivery>> fetchAssignedDeliveries(
    String accessToken,
  ) async {
    final payload = await _apiClient.getJson(
      '/api/driver/deliveries',
      bearerToken: accessToken,
    );
    final data = payload['data'];

    if (payload['success'] != true || data is! List<Object?>) {
      throw ApiException.invalidResponse();
    }

    try {
      return List<DriverDelivery>.unmodifiable(
        data.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid delivery item.');
          }
          return DriverDeliveryMapper.fromJson(item);
        }),
      );
    } on FormatException {
      throw ApiException.invalidResponse();
    }
  }

  Future<DriverDeliveryDetails> fetchDeliveryDetails(
    int deliveryId,
    String accessToken,
  ) async {
    final payload = await _apiClient.getJson(
      '/api/driver/deliveries/$deliveryId',
      bearerToken: accessToken,
    );
    final data = payload['data'];

    if (payload['success'] != true || data is! Map<String, dynamic>) {
      throw ApiException.invalidResponse();
    }

    try {
      final details = DriverDeliveryDetailsMapper.fromJson(data);
      if (details.delivery.id != deliveryId) {
        throw const FormatException('Unexpected delivery id.');
      }
      return details;
    } on FormatException {
      throw ApiException.invalidResponse();
    }
  }

  Future<DriverDelivery> startDelivery(
    int deliveryId,
    String accessToken,
  ) async {
    final payload = await _apiClient.postJson(
      '/api/driver/deliveries/$deliveryId/start',
      bearerToken: accessToken,
    );
    final data = payload['data'];

    if (payload['success'] != true || data is! Map<String, dynamic>) {
      throw ApiException.invalidResponse();
    }

    try {
      final delivery = DriverDeliveryMapper.fromJson(data);
      if (delivery.id != deliveryId ||
          delivery.status != DeliveryStatus.onTheWay) {
        throw const FormatException('Unexpected started delivery.');
      }
      return delivery;
    } on FormatException {
      throw ApiException.invalidResponse();
    }
  }

  void close() => _apiClient.close();
}
