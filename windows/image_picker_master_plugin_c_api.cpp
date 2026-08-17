#include "include/image_picker_master/image_picker_master_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "image_picker_master_plugin.h"

void ImagePickerMasterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  image_picker_master::ImagePickerMasterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
