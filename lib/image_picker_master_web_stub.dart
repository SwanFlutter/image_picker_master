// lib/image_picker_master_web_stub.dart
// Stub implementation for non-web platforms

import 'image_picker_master_platform_interface.dart';
import 'src/tools/file_picker_options.dart';
import 'src/tools/picked_file.dart';

/// A stub implementation of [ImagePickerMasterPlatform] for non-web platforms.
class ImagePickerMasterWeb extends ImagePickerMasterPlatform {
  /// Creates a new instance of [ImagePickerMasterWeb].
  ImagePickerMasterWeb();

  /// Registers this class as the default instance of [ImagePickerMasterPlatform].
  static void registerWith(dynamic registrar) {
    throw UnsupportedError(
      'Web implementation is not supported on this platform',
    );
  }

  @override
  Future<String?> getPlatformVersion() async {
    throw UnsupportedError(
      'Web implementation is not supported on this platform',
    );
  }

  @override
  Future<List<PickedFile>?> pickFiles(FilePickerOptions options) async {
    throw UnsupportedError(
      'Web implementation is not supported on this platform',
    );
  }

  @override
  Future<void> clearTemporaryFiles() async {
    throw UnsupportedError(
      'Web implementation is not supported on this platform',
    );
  }

  @override
  Future<PickedFile?> capturePhoto({
    required bool allowCompression,
    required int compressionQuality,
    required bool withData,
  }) async {
    throw UnsupportedError(
      'Web implementation is not supported on this platform',
    );
  }
}
