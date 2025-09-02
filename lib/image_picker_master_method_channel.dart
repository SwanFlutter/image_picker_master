// lib/image_picker_master_method_channel.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'image_picker_master_platform_interface.dart';
import 'src/tools/file_picker_options.dart';
import 'src/tools/picked_file.dart';

/// An implementation of [ImagePickerMasterPlatform] that uses method channels.
///
/// This class handles communication between the Dart code and the native
/// platform implementations through Flutter's method channel system.
class MethodChannelImagePickerMaster extends ImagePickerMasterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('image_picker_master');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<List<PickedFile>?> pickFiles(FilePickerOptions options) async {
    try {
      final result = await methodChannel.invokeMethod<List<dynamic>>(
        'pickFiles',
        options.toMap(),
      );

      if (result == null) return null;

      return result
          .map(
            (file) =>
                PickedFile.fromMap(Map<String, dynamic>.from(file as Map)),
          )
          .toList();
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<PickedFile?> capturePhoto({
    required bool allowCompression,
    required int compressionQuality,
    required bool withData,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<List<dynamic>>(
        'capturePhoto',
        {
          'allowCompression': allowCompression,
          'compressionQuality': compressionQuality,
          'withData': withData,
        },
      );

      if (result == null || result.isEmpty) return null;

      // Native code returns a List with one item, so we take the first element
      final firstFile = result.first as Map<dynamic, dynamic>;
      return PickedFile.fromMap(Map<String, dynamic>.from(firstFile));
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> clearTemporaryFiles() async {
    try {
      await methodChannel.invokeMethod('clearTemporaryFiles');
    } on PlatformException {
      // Handle error silently
    }
  }
}
