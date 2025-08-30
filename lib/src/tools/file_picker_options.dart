import 'package:image_picker_master/src/tools/file_type.dart';

class FilePickerOptions {
  final FileType type;
  final bool allowMultiple;
  final List<String>? allowedExtensions;
  final bool withData;
  final bool allowCompression;
  final int? compressionQuality;

  const FilePickerOptions({
    this.type = FileType.all,
    this.allowMultiple = false,
    this.allowedExtensions,
    this.withData = false,
    this.allowCompression = false,
    this.compressionQuality,
  });

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
