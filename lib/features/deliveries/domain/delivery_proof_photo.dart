import 'dart:typed_data';

class DeliveryProofPhoto {
  DeliveryProofPhoto({
    required this.fileName,
    required this.mimeType,
    required List<int> bytes,
  }) : bytes = Uint8List.fromList(bytes);

  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  int get sizeInBytes => bytes.lengthInBytes;
}
