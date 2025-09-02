#ifndef FLUTTER_PLUGIN_IMAGE_PICKER_MASTER_PLUGIN_H_
#define FLUTTER_PLUGIN_IMAGE_PICKER_MASTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <string>
#include <vector>
#include <optional>
#include <windows.h>
#include <shobjidl.h>
#include <versionhelpers.h>

// Disable GDI+ warnings that are treated as errors
#pragma warning(push)
#pragma warning(disable: 4458)  // GDI+ warning
#pragma warning(disable: 4101)  // Unused variable warning
#include <gdiplus.h>
#pragma warning(pop)

namespace image_picker_master {

    class ImagePickerMasterPlugin : public flutter::Plugin {
    public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

        explicit ImagePickerMasterPlugin(flutter::PluginRegistrarWindows *registrar = nullptr);
        virtual ~ImagePickerMasterPlugin();

        // Disallow copy and assign.
        ImagePickerMasterPlugin(const ImagePickerMasterPlugin&) = delete;
        ImagePickerMasterPlugin& operator=(const ImagePickerMasterPlugin&) = delete;

        // Called when a method is called on this plugin's channel from Dart.
        void HandleMethodCall(
                const flutter::MethodCall<flutter::EncodableValue> &method_call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    private:
        // Plugin registrar reference
        flutter::PluginRegistrarWindows* registrar_;

        // GDI+ token for image operations
        ULONG_PTR gdiplusToken_;

        // Temporary files for cleanup
        std::vector<std::string> temporary_files_;

        // Method implementations
        void PickFiles(
                const flutter::EncodableMap& arguments,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        void CapturePhoto(
                const flutter::EncodableMap& arguments,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        void ShowFilePicker(
                const std::string& file_type,
                bool allow_multiple,
                const std::vector<std::string>& allowed_extensions,
                bool with_data,
                bool allow_compression,
                int compression_quality,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        void ProcessSelectedFiles(
                IShellItemArray* pItems,
                bool with_data,
                bool allow_compression,
                int compression_quality,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        void ProcessSelectedFile(
                IShellItem* pItem,
                bool with_data,
                bool allow_compression,
                int compression_quality,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

        std::optional<flutter::EncodableValue> ProcessFileItem(
                IShellItem* pItem,
                bool with_data,
                bool allow_compression,
                int compression_quality);

        // Helper methods for image processing
        std::optional<std::string> CompressImage(
                const std::string& file_path,
                int quality);

        std::optional<std::string> ReadFileAsBase64(
                const std::string& file_path);

        std::string GetFileExtension(const std::string& file_path);

        bool IsImageFile(const std::string& file_path);

        std::string CreateTempFilePath(const std::string& extension);

        void CleanupTempFiles();

        std::vector<uint8_t> ReadFileBytes(const std::string& filePath);

        std::string GetMimeType(const std::string& extension);

        std::string GenerateUUID();

        // Image format conversion helpers
        bool ConvertToJpeg(
                const std::string& input_path,
                const std::string& output_path,
                int quality);

        bool GetImageEncoder(
                const std::wstring& format,
                CLSID* pClsid);

        // File dialog helpers
        void SetFileDialogOptions(
                IFileOpenDialog* pFileOpen,
                const std::string& file_type,
                const std::vector<std::string>& allowed_extensions);

        std::vector<COMDLG_FILTERSPEC> CreateFileFilters(
                const std::string& file_type,
                const std::vector<std::string>& allowed_extensions);

        // Error handling
        void SendError(
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
                const std::string& error_code,
                const std::string& error_message);

        // Constants
        static constexpr int DEFAULT_COMPRESSION_QUALITY = 85;
        static constexpr const char* TEMP_DIR_PREFIX = "flutter_image_picker_";
    };

}  // namespace image_picker_master

#endif  // FLUTTER_PLUGIN_IMAGE_PICKER_MASTER_PLUGIN_H_