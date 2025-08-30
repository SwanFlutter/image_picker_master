import 'package:image_picker_master/src/tools/file_type.dart';

/// Configuration options for file picking operations.
///
/// This class encapsulates all the parameters needed to customize
/// file selection behavior, including file type filtering, multiple
/// selection, compression settings, and data inclusion options.
class FilePickerOptions {
  /// The type of files to pick (all, image, video, audio, document, custom).
  final FileType type;

  /// Whether to allow selecting multiple files.
  final bool allowMultiple;

  /// List of allowed file extensions (only works with FileType.custom).
  final List<String>? allowedExtensions;

  /// Whether to include file bytes in the result.
  final bool withData;

  /// Whether to enable image compression for image files.
  final bool allowCompression;

  /// The compression quality (0-100) when compression is enabled.
  final int? compressionQuality;

  /// Creates a new [FilePickerOptions] instance.
  ///
  /// [type] defaults to [FileType.all].
  /// [allowMultiple] defaults to false.
  /// [withData] defaults to false.
  /// [allowCompression] defaults to false.
  const FilePickerOptions({
    this.type = FileType.all,
    this.allowMultiple = false,
    this.allowedExtensions,
    this.withData = false,
    this.allowCompression = false,
    this.compressionQuality,
  });

  /// Converts this options object to a map for platform channel communication.
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'allowMultiple': allowMultiple,
      'allowedExtensions': allowedExtensions,
      'withData': withData,
      'allowCompression': allowCompression,
      'compressionQuality': compressionQuality,
    };
  }
}
