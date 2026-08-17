import 'package:pelekapro_mobile/features/deliveries/data/models/driver_delivery_mapper.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure_reason.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';

abstract final class DriverDeliveryDetailsMapper {
  static DriverDeliveryDetails fromJson(Map<String, dynamic> json) {
    final rawReasons = json['failure_reasons'];
    if (rawReasons is! List<Object?>) {
      throw const FormatException('Expected a failure reason list.');
    }

    return DriverDeliveryDetails(
      delivery: DriverDeliveryMapper.fromJson(json),
      failureReasons: List<DeliveryFailureReason>.unmodifiable(
        rawReasons.map(_failureReasonFromJson),
      ),
    );
  }

  static DeliveryFailureReason _failureReasonFromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected a failure reason object.');
    }

    final id = value['id'];
    final name = value['name'];
    if (id is! int || id <= 0 || name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid failure reason.');
    }

    return DeliveryFailureReason(id: id, name: name.trim());
  }
}
