import 'dart:typed_data';

class MultipartFileData {
  MultipartFileData({
    required this.fieldName,
    required this.fileName,
    required List<int> bytes,
  }) : bytes = Uint8List.fromList(bytes);

  final String fieldName;
  final String fileName;
  final Uint8List bytes;
}
