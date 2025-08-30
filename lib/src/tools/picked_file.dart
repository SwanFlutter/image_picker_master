import 'dart:typed_data';

class PickedFile {
  final String path;
  final String name;
  final int size;
  final String? mimeType;
  final Uint8List? bytes;

  PickedFile({
    required this.path,
    required this.name,
    required this.size,
    this.mimeType,
    this.bytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'size': size,
      'mimeType': mimeType,
      'bytes': bytes,
    };
  }

  factory PickedFile.fromMap(Map<String, dynamic> map) {
    return PickedFile(
      path: map['path'] ?? '',
      name: map['name'] ?? '',
      size: map['size'] ?? 0,
      mimeType: map['mimeType'],
      bytes: map['bytes'],
    );
  }
}
