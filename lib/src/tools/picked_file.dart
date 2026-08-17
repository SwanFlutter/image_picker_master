import 'dart:typed_data';

/// Represents a file that has been picked by the user.
///
/// This class contains all the information about a selected file,
/// including its path, name, size, MIME type, and optionally its bytes.
class PickedFile {
  /// The absolute path to the picked file.
  final String path;

  /// The name of the picked file including its extension.
  final String name;

  /// The size of the picked file in bytes.
  final int size;

  /// The MIME type of the picked file (e.g., 'image/jpeg', 'application/pdf').
  final String? mimeType;

  /// The bytes of the picked file (only available when withData is true).
  final Uint8List? bytes;

  /// Creates a new [PickedFile] instance.
  ///
  /// [path], [name], and [size] are required parameters.
  /// [mimeType] and [bytes] are optional.
  PickedFile({
    required this.path,
    required this.name,
    required this.size,
    this.mimeType,
    this.bytes,
  });

  /// Converts this [PickedFile] to a map representation.
  ///
  /// This is useful for serialization and platform channel communication.
  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'size': size,
      'mimeType': mimeType,
      'bytes': bytes,
    };
  }

  /// Creates a [PickedFile] instance from a map representation.
  ///
  /// This factory constructor is used for deserialization from
  /// platform channel responses.
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
