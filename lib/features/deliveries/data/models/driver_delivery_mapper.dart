import 'package:pelekapro_mobile/features/deliveries/domain/delivery_customer.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_item.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_payment.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_requirements.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_stop.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_timestamps.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';

abstract final class DriverDeliveryMapper {
  static DriverDelivery fromJson(Map<String, dynamic> json) {
    final pickup = _requiredMap(json, 'pickup');
    final dropoff = _requiredMap(json, 'dropoff');
    final customer = _requiredMap(json, 'customer');
    final payment = _requiredMap(json, 'payment');
    final requirements = _requiredMap(json, 'requirements');
    final timestamps = _requiredMap(json, 'timestamps');
    final customerAddress = _nullableMap(json, 'customer_address');

    return DriverDelivery(
      id: _requiredInt(json, 'id'),
      deliveryNumber: _requiredString(json, 'delivery_number'),
      trackingCode: _requiredString(json, 'tracking_code'),
      status: DeliveryStatus.fromApi(_requiredString(json, 'status')),
      pickup: _stopFrom(pickup),
      dropoff: _stopFrom(dropoff),
      customer: DeliveryCustomer(
        id: _requiredInt(customer, 'id'),
        name: _requiredString(customer, 'name'),
        phone: _requiredString(customer, 'phone'),
      ),
      customerAddress: customerAddress == null
          ? null
          : DeliveryCustomerAddress(
              label: _nullableString(customerAddress, 'label'),
              region: _nullableString(customerAddress, 'region'),
              district: _nullableString(customerAddress, 'district'),
              ward: _nullableString(customerAddress, 'ward'),
              street: _nullableString(customerAddress, 'street'),
              landmark: _nullableString(customerAddress, 'landmark'),
              buildingInstruction: _nullableString(
                customerAddress,
                'building_instruction',
              ),
              latitude: _nullableDecimal(customerAddress, 'latitude'),
              longitude: _nullableDecimal(customerAddress, 'longitude'),
            ),
      items: List<DeliveryItem>.unmodifiable(
        _requiredList(json, 'items').map(_itemFrom),
      ),
      payment: DeliveryPayment(
        method: _requiredString(payment, 'method'),
        amountToCollect: _requiredDecimal(payment, 'amount_to_collect'),
        deliveryFee: _requiredDecimal(payment, 'delivery_fee'),
        record: _paymentRecordFrom(_nullableMap(payment, 'payment_record')),
      ),
      requirements: DeliveryRequirements(
        pinRequired: _requiredBool(requirements, 'pin_required'),
        proofSupported: _requiredBool(requirements, 'proof_supported'),
        availableProofTypes: List<String>.unmodifiable(
          _requiredList(
            requirements,
            'available_proof_types',
          ).map(_stringListValue),
        ),
      ),
      timestamps: DeliveryTimestamps(
        assignedAt: _nullableDate(timestamps, 'assigned_at'),
        startedAt: _nullableDate(timestamps, 'started_at'),
        arrivedAt: _nullableDate(timestamps, 'arrived_at'),
        deliveredAt: _nullableDate(timestamps, 'delivered_at'),
        failedAt: _nullableDate(timestamps, 'failed_at'),
        cancelledAt: _nullableDate(timestamps, 'cancelled_at'),
      ),
    );
  }

  static DeliveryStop _stopFrom(Map<String, dynamic> json) {
    return DeliveryStop(
      name: _nullableString(json, 'name'),
      phone: _nullableString(json, 'phone'),
      address: _nullableString(json, 'address'),
      latitude: _nullableDecimal(json, 'latitude'),
      longitude: _nullableDecimal(json, 'longitude'),
    );
  }

  static DeliveryItem _itemFrom(Object? value) {
    final json = _asMap(value, 'items[]');
    return DeliveryItem(
      id: _requiredInt(json, 'id'),
      deliveryId: _requiredInt(json, 'delivery_id'),
      name: _requiredString(json, 'item_name'),
      quantity: _requiredInt(json, 'quantity'),
      amount: _requiredDecimal(json, 'amount'),
      description: _nullableString(json, 'description'),
      createdAt: _nullableDate(json, 'created_at'),
      updatedAt: _nullableDate(json, 'updated_at'),
    );
  }

  static DeliveryPaymentRecord? _paymentRecordFrom(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    return DeliveryPaymentRecord(
      method: _requiredString(json, 'payment_method'),
      expectedAmount: _requiredDecimal(json, 'expected_amount'),
      collectedAmount: _requiredDecimal(json, 'collected_amount'),
      status: _requiredString(json, 'payment_status'),
    );
  }

  static Map<String, dynamic> _requiredMap(
    Map<String, dynamic> json,
    String key,
  ) {
    return _asMap(json[key], key);
  }

  static Map<String, dynamic>? _nullableMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    return value == null ? null : _asMap(value, key);
  }

  static Map<String, dynamic> _asMap(Object? value, String field) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    throw FormatException('Expected an object for $field.');
  }

  static List<Object?> _requiredList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is List<Object?>) {
      return value;
    }

    throw FormatException('Expected a list for $key.');
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw FormatException('Expected a non-empty string for $key.');
  }

  static String? _nullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    throw FormatException('Expected a string or null for $key.');
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }

    throw FormatException('Expected an integer for $key.');
  }

  static bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) {
      return value;
    }

    throw FormatException('Expected a boolean for $key.');
  }

  static double _requiredDecimal(Map<String, dynamic> json, String key) {
    final parsed = _decimalValue(json[key]);
    if (parsed != null) {
      return parsed;
    }

    throw FormatException('Expected a decimal value for $key.');
  }

  static double? _nullableDecimal(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    final parsed = _decimalValue(value);
    if (parsed != null) {
      return parsed;
    }

    throw FormatException('Expected a decimal value or null for $key.');
  }

  static double? _decimalValue(Object? value) {
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };

    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static DateTime? _nullableDate(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }

    throw FormatException('Expected an ISO-8601 timestamp or null for $key.');
  }

  static String _stringListValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw const FormatException('Expected a non-empty string in the list.');
  }
}
