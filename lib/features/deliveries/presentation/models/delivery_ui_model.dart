import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';

class DeliveryUiModel {
  const DeliveryUiModel({
    required this.id,
    required this.code,
    required this.trackingCode,
    required this.recipientName,
    required this.recipientPhone,
    required this.pickupArea,
    required this.pickupAddress,
    required this.dropoffArea,
    required this.dropoffAddress,
    required this.assignedAt,
    required this.itemCount,
    required this.itemDescription,
    required this.amountToCollect,
    required this.expectedCollectionAmount,
    required this.paymentMethod,
    required this.collectionMethod,
    required this.paymentCollectionRequired,
    required this.note,
    required this.status,
    required this.lastUpdatedAt,
    required this.proofSupported,
    required this.photoProofSupported,
  });

  factory DeliveryUiModel.fromDomain(DriverDelivery delivery) {
    final itemCount = delivery.items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
    final itemNames = delivery.items
        .map((item) => item.name.trim())
        .where((name) => name.isNotEmpty)
        .take(2)
        .toList(growable: false);
    final instruction = delivery.customerAddress?.buildingInstruction?.trim();
    final landmark = delivery.customerAddress?.landmark?.trim();
    final pickupAddress = _firstAvailable([
      delivery.pickup.address,
      delivery.pickup.name,
    ], fallback: 'Pickup details unavailable');
    final dropoffAddress = _firstAvailable([
      delivery.dropoff.address,
      delivery.customerAddress?.street,
    ], fallback: 'Drop-off details unavailable');
    final paymentRecord = delivery.payment.record;
    final collectionMethod =
        paymentRecord?.method ??
        _normalizedPaymentMethod(delivery.payment.method);
    final expectedCollection =
        paymentRecord?.expectedAmount ?? delivery.payment.amountToCollect;
    final paymentCollectionRequired =
        expectedCollection > 0 &&
        collectionMethod != 'none' &&
        collectionMethod != 'prepaid';

    return DeliveryUiModel(
      id: delivery.id,
      code: delivery.deliveryNumber,
      trackingCode: delivery.trackingCode,
      recipientName: delivery.customer.name,
      recipientPhone: delivery.customer.phone,
      pickupArea: _compactLocation(pickupAddress),
      pickupAddress: pickupAddress,
      dropoffArea: _dropoffLocation(delivery),
      dropoffAddress: dropoffAddress,
      assignedAt: delivery.timestamps.assignedAt,
      itemCount: itemCount,
      itemDescription: itemNames.isEmpty
          ? 'Item details unavailable'
          : itemNames.join(', '),
      amountToCollect: delivery.payment.amountToCollect,
      expectedCollectionAmount: expectedCollection,
      paymentMethod: _readableApiValue(delivery.payment.method),
      collectionMethod: _readableApiValue(collectionMethod),
      paymentCollectionRequired: paymentCollectionRequired,
      note: instruction != null && instruction.isNotEmpty
          ? instruction
          : landmark != null && landmark.isNotEmpty
          ? landmark
          : null,
      status: delivery.status,
      lastUpdatedAt: delivery.timestamps.latest,
      proofSupported: delivery.requirements.proofSupported,
      photoProofSupported:
          delivery.requirements.proofSupported &&
          delivery.requirements.availableProofTypes.contains('photo'),
    );
  }

  final int id;
  final String code;
  final String trackingCode;
  final String recipientName;
  final String recipientPhone;
  final String pickupArea;
  final String pickupAddress;
  final String dropoffArea;
  final String dropoffAddress;
  final DateTime? assignedAt;
  final int itemCount;
  final String itemDescription;
  final double amountToCollect;
  final double expectedCollectionAmount;
  final String paymentMethod;
  final String collectionMethod;
  final bool paymentCollectionRequired;
  final String? note;
  final DeliveryStatus status;
  final DateTime? lastUpdatedAt;
  final bool proofSupported;
  final bool photoProofSupported;

  DeliveryUiModel copyWith({DeliveryStatus? status}) {
    return DeliveryUiModel(
      id: id,
      code: code,
      trackingCode: trackingCode,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      pickupArea: pickupArea,
      pickupAddress: pickupAddress,
      dropoffArea: dropoffArea,
      dropoffAddress: dropoffAddress,
      assignedAt: assignedAt,
      itemCount: itemCount,
      itemDescription: itemDescription,
      amountToCollect: amountToCollect,
      expectedCollectionAmount: expectedCollectionAmount,
      paymentMethod: paymentMethod,
      collectionMethod: collectionMethod,
      paymentCollectionRequired: paymentCollectionRequired,
      note: note,
      status: status ?? this.status,
      lastUpdatedAt: lastUpdatedAt,
      proofSupported: proofSupported,
      photoProofSupported: photoProofSupported,
    );
  }

  static String _dropoffLocation(DriverDelivery delivery) {
    final address = delivery.customerAddress;
    if (address == null) {
      return _compactLocation(
        _firstAvailable([
          delivery.dropoff.address,
          delivery.dropoff.name,
        ], fallback: 'Drop-off details unavailable'),
      );
    }

    final locality = _firstAvailable([
      address.ward,
      address.district,
    ], fallback: '');
    final parts = [locality, address.region]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .fold<List<String>>(<String>[], (unique, part) {
          if (!unique.any(
            (existing) => existing.toLowerCase() == part.toLowerCase(),
          )) {
            unique.add(part);
          }
          return unique;
        });

    return parts.isEmpty
        ? _compactLocation(
            _firstAvailable([
              delivery.dropoff.address,
              delivery.dropoff.name,
            ], fallback: 'Drop-off details unavailable'),
          )
        : parts.take(2).join(', ');
  }

  static String _compactLocation(String value) {
    final parts = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length <= 2) {
      return value;
    }
    return parts.sublist(parts.length - 2).join(', ');
  }

  static String _firstAvailable(
    Iterable<String?> values, {
    required String fallback,
  }) {
    for (final value in values) {
      final candidate = value?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return fallback;
  }

  static String _readableApiValue(String value) {
    final words = value
        .split('_')
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return 'Not specified';
    }

    final label = words.join(' ');
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  static String _normalizedPaymentMethod(String value) {
    return switch (value.trim().toLowerCase()) {
      'mobile_money' => 'mobile_money',
      'bank' => 'bank',
      'prepaid' => 'prepaid',
      'none' => 'none',
      _ => 'cash',
    };
  }
}
