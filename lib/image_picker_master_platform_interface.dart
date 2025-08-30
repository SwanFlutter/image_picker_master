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

  /// Clears all temporary files created by the plugin.
  ///
  /// Platform implementations should override this method to clean up
  /// temporary files on their respective platforms.
  Future<void> clearTemporaryFiles() {
    throw UnimplementedError('clearTemporaryFiles() has not been implemented.');
  }
}
