import 'package:pelekapro_mobile/features/deliveries/domain/delivery_customer.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_item.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_payment.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_requirements.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_status.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_stop.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_timestamps.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';

DriverDelivery driverDeliveryFixture({
  int id = 101,
  String code = 'PP-24031',
  String recipientName = 'Asha Juma',
  String recipientPhone = '+255 712 345 678',
  String pickupAddress = 'Uhuru Street, Kariakoo, Dar es Salaam',
  String dropoffAddress = 'Mwai Kibaki Road, Mikocheni, Dar es Salaam',
  String dropoffWard = 'Mikocheni',
  DeliveryStatus status = DeliveryStatus.assigned,
  String itemName = 'Documents',
  double amountToCollect = 25000,
  String? instruction = 'Call on arrival',
  DateTime? assignedAt,
}) {
  final assigned = assignedAt ?? DateTime.utc(2026, 8, 17, 7);
  final activeAt = status.isActive || status.isDone
      ? assigned.add(const Duration(minutes: 30))
      : null;

  return DriverDelivery(
    id: id,
    deliveryNumber: code,
    trackingCode: 'TRACK-$id',
    status: status,
    pickup: DeliveryStop(
      name: 'PelekaPro pickup',
      phone: '+255 700 000 001',
      address: pickupAddress,
      latitude: -6.7924,
      longitude: 39.2083,
    ),
    dropoff: DeliveryStop(
      name: recipientName,
      phone: recipientPhone,
      address: dropoffAddress,
      latitude: -6.769,
      longitude: 39.234,
    ),
    customer: DeliveryCustomer(
      id: id + 1000,
      name: recipientName,
      phone: recipientPhone,
    ),
    customerAddress: DeliveryCustomerAddress(
      label: 'Home',
      region: 'Dar es Salaam',
      district: 'Kinondoni',
      ward: dropoffWard,
      street: dropoffAddress,
      latitude: -6.769,
      longitude: 39.234,
      buildingInstruction: instruction,
    ),
    items: [
      DeliveryItem(
        id: id + 2000,
        deliveryId: id,
        name: itemName,
        quantity: 1,
        amount: amountToCollect,
        createdAt: assigned,
        updatedAt: assigned,
      ),
    ],
    payment: DeliveryPayment(
      method: 'cash_on_delivery',
      amountToCollect: amountToCollect,
      deliveryFee: 3000,
      record: DeliveryPaymentRecord(
        method: 'cash',
        expectedAmount: amountToCollect,
        collectedAmount: 0,
        status: 'pending',
      ),
    ),
    requirements: const DeliveryRequirements(
      pinRequired: true,
      proofSupported: true,
      availableProofTypes: ['photo', 'signature'],
    ),
    timestamps: DeliveryTimestamps(
      assignedAt: assigned,
      startedAt: activeAt,
      arrivedAt: status == DeliveryStatus.arrived ? activeAt : null,
      deliveredAt: status == DeliveryStatus.delivered ? activeAt : null,
      failedAt: status == DeliveryStatus.failed ? activeAt : null,
      cancelledAt: status == DeliveryStatus.cancelled ? activeAt : null,
    ),
  );
}

List<DriverDelivery> assignedDeliveriesFixture() {
  return [
    driverDeliveryFixture(),
    driverDeliveryFixture(
      id: 102,
      code: 'PP-24032',
      recipientName: 'Neema Joseph',
      recipientPhone: '+255 754 210 987',
      pickupAddress: 'Shekilango Road, Sinza, Dar es Salaam',
      dropoffAddress: 'Haile Selassie Road, Oysterbay, Dar es Salaam',
      dropoffWard: 'Oysterbay',
      status: DeliveryStatus.onTheWay,
      itemName: 'Parcels',
      amountToCollect: 18000,
      instruction: 'Use the main entrance',
    ),
    driverDeliveryFixture(
      id: 103,
      code: 'PP-24033',
      recipientName: 'Baraka Mtei',
      recipientPhone: '+255 689 430 125',
      pickupAddress: 'Morogoro Road, Ubungo, Dar es Salaam',
      dropoffAddress: 'Chole Road, Masaki, Dar es Salaam',
      dropoffWard: 'Masaki',
      status: DeliveryStatus.arrived,
      itemName: 'Parcel',
      amountToCollect: 32000,
    ),
    driverDeliveryFixture(
      id: 104,
      code: 'PP-24034',
      recipientName: 'Rehema Kweka',
      recipientPhone: '+255 713 880 442',
      pickupAddress: 'Sam Nujoma Road, Mwenge, Dar es Salaam',
      dropoffAddress: 'Kawawa Road, Kinondoni, Dar es Salaam',
      dropoffWard: 'Kinondoni',
      status: DeliveryStatus.delivered,
      amountToCollect: 12000,
      instruction: null,
    ),
  ];
}
