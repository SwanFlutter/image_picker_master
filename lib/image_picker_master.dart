import 'image_picker_master_platform_interface.dart';
import 'src/tools/file_picker_options.dart';
import 'src/tools/file_type.dart';
import 'src/tools/picked_file.dart';

export 'src/tools/picked_file.dart';
export 'src/tools/file_type.dart';
export 'src/tools/file_picker_options.dart';

class ImagePickerMaster {
  static ImagePickerMaster? _instance;
  static ImagePickerMaster get instance => _instance ??= ImagePickerMaster._();

  ImagePickerMaster._();

  Future<String?> getPlatformVersion() {
    return ImagePickerMasterPlatform.instance.getPlatformVersion();
  }

  Future<List<PickedFile>?> pickFiles({
    FileType type = FileType.all,
    bool allowMultiple = false,
    List<String>? allowedExtensions,
    bool withData = false,
    bool allowCompression = false,
    int? compressionQuality,
  }) async {
    final options = FilePickerOptions(
      type: type,
      allowMultiple: allowMultiple,
      allowedExtensions: allowedExtensions,
      withData: withData,
      allowCompression: allowCompression,
      compressionQuality: compressionQuality,
    );

    return ImagePickerMasterPlatform.instance.pickFiles(options);
  }

  Future<PickedFile?> pickImage({
    bool allowCompression = true,
    int compressionQuality = 80,
    bool withData = false,
  }) async {
    final result = await pickFiles(
      type: FileType.image,
      allowMultiple: false,
      allowCompression: allowCompression,
      compressionQuality: compressionQuality,
      withData: withData,
    );

    return result?.isNotEmpty == true ? result!.first : null;
  }

  Future<List<PickedFile>?> pickImages({
    bool allowMultiple = true,
    bool allowCompression = true,
    int compressionQuality = 80,
    bool withData = false,
  }) async {
    return pickFiles(
      type: FileType.image,
      allowMultiple: allowMultiple,
      allowCompression: allowCompression,
      compressionQuality: compressionQuality,
      withData: withData,
    );
  }

  Future<PickedFile?> pickVideo({bool withData = false}) async {
    final result = await pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: withData,
    );

    return result?.isNotEmpty == true ? result!.first : null;
  }

  Future<List<PickedFile>?> pickVideos({
    bool allowMultiple = true,
    bool withData = false,
  }) async {
    return pickFiles(
      type: FileType.video,
      allowMultiple: allowMultiple,
      withData: withData,
    );
  }

  Future<PickedFile?> pickAudio({bool withData = false}) async {
    final result = await pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: withData,
    );

    return result?.isNotEmpty == true ? result!.first : null;
  }

  Future<List<PickedFile>?> pickAudios({
    bool allowMultiple = true,
    bool withData = false,
  }) async {
    return pickFiles(
      type: FileType.audio,
      allowMultiple: allowMultiple,
      withData: withData,
    );
  }

  Future<PickedFile?> pickDocument({
    List<String>? allowedExtensions,
    bool withData = false,
  }) async {
    final result = await pickFiles(
      type: FileType.document,
      allowMultiple: false,
      allowedExtensions: allowedExtensions,
      withData: withData,
    );

    return result?.isNotEmpty == true ? result!.first : null;
  }

  Future<List<PickedFile>?> pickDocuments({
    bool allowMultiple = true,
    List<String>? allowedExtensions,
    bool withData = false,
  }) async {
    return pickFiles(
      type: FileType.document,
      allowMultiple: allowMultiple,
      allowedExtensions: allowedExtensions,
      withData: withData,
    );
  }

  Future<void> clearTemporaryFiles() async {
    return ImagePickerMasterPlatform.instance.clearTemporaryFiles();
  }
}
