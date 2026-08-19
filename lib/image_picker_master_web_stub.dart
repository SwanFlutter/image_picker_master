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
    // No-op for non-web platforms
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

  @override
  Future<String?> resizeImageForCropper({
    required String path,
    int maxSize = 1024,
  }) async {
    throw UnsupportedError(
      'Web implementation is not supported on this platform',
    );
  }

  @override
  Future<String?> cropImageNative({
    required String path,
    required double cropX,
    required double cropY,
    required double cropW,
    required double cropH,
    required double containerW,
    required double containerH,
    int rotation = 0,
    int quality = 85,
    String format = 'jpeg',
    int maxSize = 1200,
  }) async {
    throw UnsupportedError(
      'Web implementation is not supported on this platform',
    );
  }
}
