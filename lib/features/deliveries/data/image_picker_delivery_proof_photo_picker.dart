import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_proof_photo.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_proof_photo_picker.dart';

class ImagePickerDeliveryProofPhotoPicker implements DeliveryProofPhotoPicker {
  ImagePickerDeliveryProofPhotoPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  static const maxFileSizeInBytes = 5 * 1024 * 1024;

  final ImagePicker _imagePicker;

  @override
  Future<DeliveryProofPhoto?> pick(DeliveryProofPhotoSource source) async {
    try {
      final selected = await _imagePicker.pickImage(
        source: switch (source) {
          DeliveryProofPhotoSource.camera => ImageSource.camera,
          DeliveryProofPhotoSource.gallery => ImageSource.gallery,
        },
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
        requestFullMetadata: false,
      );
      if (selected == null) {
        return null;
      }

      final mimeType = _supportedMimeType(selected.mimeType, selected.name);
      if (mimeType == null) {
        throw const DeliveryProofPhotoFailure(
          'Choose a JPEG, PNG, or WebP image.',
        );
      }

      final bytes = await selected.readAsBytes();
      if (bytes.isEmpty) {
        throw const DeliveryProofPhotoFailure(
          'The selected photo is empty. Choose another photo.',
        );
      }
      if (bytes.lengthInBytes > maxFileSizeInBytes) {
        throw const DeliveryProofPhotoFailure(
          'The proof photo must be 5 MB or smaller.',
        );
      }

      return DeliveryProofPhoto(
        fileName: _safeFileName(selected.name, mimeType),
        mimeType: mimeType,
        bytes: bytes,
      );
    } on DeliveryProofPhotoFailure {
      rethrow;
    } on PlatformException {
      throw const DeliveryProofPhotoFailure(
        'The photo could not be opened. Check camera access and try again.',
      );
    } on Object {
      throw const DeliveryProofPhotoFailure(
        'The photo could not be read. Choose another photo.',
      );
    }
  }

  static String? _supportedMimeType(String? reportedType, String fileName) {
    final normalizedType = reportedType?.trim().toLowerCase();
    if (normalizedType == 'image/jpeg' ||
        normalizedType == 'image/png' ||
        normalizedType == 'image/webp') {
      return normalizedType;
    }

    final normalizedName = fileName.toLowerCase();
    if (normalizedName.endsWith('.jpg') || normalizedName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (normalizedName.endsWith('.png')) {
      return 'image/png';
    }
    if (normalizedName.endsWith('.webp')) {
      return 'image/webp';
    }
    return null;
  }

  static String _safeFileName(String originalName, String mimeType) {
    final name = originalName.trim().split(RegExp(r'[/\\]')).last;
    if (name.isNotEmpty) {
      return name;
    }
    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    return 'delivery-proof.$extension';
  }
}
