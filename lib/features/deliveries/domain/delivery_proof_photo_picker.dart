import 'package:pelekapro_mobile/features/deliveries/domain/delivery_proof_photo.dart';

enum DeliveryProofPhotoSource { camera, gallery }

abstract interface class DeliveryProofPhotoPicker {
  Future<DeliveryProofPhoto?> pick(DeliveryProofPhotoSource source);
}

class DeliveryProofPhotoFailure implements Exception {
  const DeliveryProofPhotoFailure(this.message);

  final String message;

  @override
  String toString() => 'DeliveryProofPhotoFailure: $message';
}
