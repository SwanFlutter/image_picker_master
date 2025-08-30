// lib/image_picker_master_platform_interface.dart
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'image_picker_master_method_channel.dart';
import 'src/tools/file_picker_options.dart';
import 'src/tools/picked_file.dart';

abstract class ImagePickerMasterPlatform extends PlatformInterface {
  ImagePickerMasterPlatform() : super(token: _token);

  static final Object _token = Object();

  static ImagePickerMasterPlatform _instance = MethodChannelImagePickerMaster();

  static ImagePickerMasterPlatform get instance => _instance;

  static set instance(ImagePickerMasterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<List<PickedFile>?> pickFiles(FilePickerOptions options) {
    throw UnimplementedError('pickFiles() has not been implemented.');
  }

  Future<void> clearTemporaryFiles() {
    throw UnimplementedError('clearTemporaryFiles() has not been implemented.');
  }
}
