import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_master/image_picker_master.dart';
import 'package:image_picker_master/image_picker_master_method_channel.dart';
import 'package:image_picker_master/image_picker_master_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockImagePickerMasterPlatform
    with MockPlatformInterfaceMixin
    implements ImagePickerMasterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> clearTemporaryFiles() {
    throw UnimplementedError();
  }

  @override
  Future<List<PickedFile>?> pickFiles(FilePickerOptions options) {
    throw UnimplementedError();
  }

  @override
  Future<PickedFile?> capturePhoto({
    required bool allowCompression,
    required int compressionQuality,
    required bool withData,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  final ImagePickerMasterPlatform initialPlatform =
      ImagePickerMasterPlatform.instance;

  test('$MethodChannelImagePickerMaster is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelImagePickerMaster>());
  });

  test('getPlatformVersion', () async {});
}
