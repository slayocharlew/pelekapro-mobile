import 'package:pelekapro_mobile/features/deliveries/domain/delivery_proof_photo.dart';

class DeliveryCompletionRequest {
  const DeliveryCompletionRequest({
    this.receiverName,
    this.receiverPhone,
    this.proofPhoto,
    this.proofNote,
    this.collectedAmount,
    this.paymentReference,
    this.note,
    this.deliveredLatitude,
    this.deliveredLongitude,
  });

  final String? receiverName;
  final String? receiverPhone;
  final DeliveryProofPhoto? proofPhoto;
  final String? proofNote;
  final double? collectedAmount;
  final String? paymentReference;
  final String? note;
  final double? deliveredLatitude;
  final double? deliveredLongitude;

  Map<String, dynamic> toJson() {
    return {
      'receiver_name': ?_trimmed(receiverName),
      'receiver_phone': ?_trimmed(receiverPhone),
      'proof_note': ?_trimmed(proofNote),
      'collected_amount': ?collectedAmount,
      'payment_reference': ?_trimmed(paymentReference),
      'note': ?_trimmed(note),
      'delivered_latitude': ?deliveredLatitude,
      'delivered_longitude': ?deliveredLongitude,
    };
  }

  Map<String, String> toMultipartFields() {
    final fields = <String, String>{
      for (final entry in toJson().entries) entry.key: entry.value.toString(),
    };
    if (proofPhoto != null) {
      fields['proof_type'] = 'photo';
    }
    return fields;
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
