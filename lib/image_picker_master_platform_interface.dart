// lib/image_picker_master_platform_interface.dart
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'image_picker_master_method_channel.dart';
import 'src/tools/file_picker_options.dart';
import 'src/tools/picked_file.dart';

/// The interface that implementations of image_picker_master must implement.
///
/// Platform implementations should extend this class rather than implement it as `ImagePickerMasterPlatform`.
/// Extending this class (using `extends`) ensures that the subclass will get the default
/// implementation, while platform implementations that `implements` this interface will be
/// broken by newly added [ImagePickerMasterPlatform] methods.
abstract class ImagePickerMasterPlatform extends PlatformInterface {
  /// Constructs a ImagePickerMasterPlatform.
  ImagePickerMasterPlatform() : super(token: _token);

  /// Token for verifying platform interface implementations.
  static final Object _token = Object();

  /// The default instance of [ImagePickerMasterPlatform] to use.
  static ImagePickerMasterPlatform _instance = MethodChannelImagePickerMaster();

  /// The default instance of [ImagePickerMasterPlatform] to use.
  ///
  /// Defaults to [MethodChannelImagePickerMaster].
  static ImagePickerMasterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ImagePickerMasterPlatform] when
  /// they register themselves.
  static set instance(ImagePickerMasterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the platform version string.
  ///
  /// Platform implementations should override this method to return
  /// the actual platform version.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Picks files from the device storage based on the provided options.
  ///
  /// Platform implementations should override this method to handle
  /// file picking on their respective platforms.
  Future<List<PickedFile>?> pickFiles(FilePickerOptions options) {
    throw UnimplementedError('pickFiles() has not been implemented.');
  }

  /// Captures a photo using the device camera.
  ///
  /// Platform implementations should override this method to handle
  /// camera capture on their respective platforms.
  Future<PickedFile?> capturePhoto({
    required bool allowCompression,
    required int compressionQuality,
    required bool withData,
  }) {
    throw UnimplementedError('capturePhoto() has not been implemented.');
  }

  /// Clears all temporary files created by the plugin.
  ///
  /// Platform implementations should override this method to clean up
  /// temporary files on their respective platforms.
  Future<void> clearTemporaryFiles() {
    throw UnimplementedError('clearTemporaryFiles() has not been implemented.');
  }

  Future<String?> resizeImageForCropper({
    required String path,
    int maxSize = 1024,
  }) {
    throw UnimplementedError(
      'resizeImageForCropper() has not been implemented.',
    );
  }

  /// Crops an image natively without going through a Dart isolate.
  ///
  /// Uses Android's `BitmapFactory.inSampleSize` / platform-native equivalents
  /// to decode only a fraction of the pixels, making resize ~50–150 ms instead
  /// of the ~10 s that pure-Dart decode takes on a 2+ MB JPEG.
  ///
  /// [path] absolute path (or object URL on web) of the source image.
  /// [cropX]/[cropY] top-left of the crop rect in container coordinates.
  /// [cropW]/[cropH] size of the crop rect in container coordinates.
  /// [containerW]/[containerH] size of the Flutter widget that displayed the image.
  /// [rotation] clockwise degrees applied before cropping (0, 90, 180, 270).
  /// [quality] JPEG/WebP encode quality 0–100 (default 85, ignored for PNG).
  /// [format] output format: `"jpeg"` | `"png"` | `"webp_lossy"` | `"webp_lossless"`.
  /// [maxSize] max edge length used when decoding the source (default 1200).
  ///
  /// Returns the absolute path of the cropped file, or `null` on failure.
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
  }) {
    throw UnimplementedError('cropImageNative() has not been implemented.');
  }
}
