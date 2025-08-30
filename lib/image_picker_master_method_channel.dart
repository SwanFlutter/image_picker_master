// lib/image_picker_master_method_channel.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'image_picker_master_platform_interface.dart';
import 'src/tools/file_picker_options.dart';
import 'src/tools/picked_file.dart';

class MethodChannelImagePickerMaster extends ImagePickerMasterPlatform {
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
  Future<void> clearTemporaryFiles() async {
    try {
      await methodChannel.invokeMethod('clearTemporaryFiles');
    } on PlatformException {
      // Handle error silently
    }
  }
}
