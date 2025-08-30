#include "image_picker_master_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <filesystem>
#include <fstream>
#include <objbase.h>   // COM functions
#include <combaseapi.h> // For CoCreateGuid

#pragma comment(lib, "comdlg32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "rpcrt4.lib")  // UUID library

using namespace Gdiplus;
namespace image_picker_master {
    namespace fs = std::filesystem;

// static
    void ImagePickerMasterPlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarWindows *registrar) {
        auto channel =
                std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                        registrar->messenger(), "image_picker_master",
                                &flutter::StandardMethodCodec::GetInstance());
        auto plugin = std::make_unique<ImagePickerMasterPlugin>(registrar);
        channel->SetMethodCallHandler(
                [plugin_pointer = plugin.get()](const auto &call, auto result) {
                    plugin_pointer->HandleMethodCall(call, std::move(result));
                });
        registrar->AddPlugin(std::move(plugin));
    }

    ImagePickerMasterPlugin::ImagePickerMasterPlugin(flutter::PluginRegistrarWindows *registrar)
            : registrar_(registrar), gdiplusToken_(0) {
        if (registrar_) {
            // Initialize GDI+
            GdiplusStartupInput gdiplusStartupInput;
            GdiplusStartup(&gdiplusToken_, &gdiplusStartupInput, NULL);

            // Initialize COM
            CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
        }
    }

    ImagePickerMasterPlugin::~ImagePickerMasterPlugin() {
        // Cleanup temporary files
        CleanupTempFiles();

        // Shutdown GDI+
        if (gdiplusToken_) {
            GdiplusShutdown(gdiplusToken_);
        }

        // Uninitialize COM
        CoUninitialize();
    }

    void ImagePickerMasterPlugin::HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue> &method_call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (method_call.method_name().compare("getPlatformVersion") == 0) {
            std::ostringstream version_stream;
            version_stream << "Windows ";
            if (IsWindows10OrGreater()) {
                version_stream << "10+";
            } else if (IsWindows8OrGreater()) {
                version_stream << "8";
            } else if (IsWindows7OrGreater()) {
                version_stream << "7";
            }
            result->Success(flutter::EncodableValue(version_stream.str()));
        }
        else if (method_call.method_name().compare("pickFiles") == 0) {
            const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
            if (arguments) {
                PickFiles(*arguments, std::move(result));
            } else {
                result->Error("INVALID_ARGUMENTS", "Invalid arguments provided");
            }
        }
        else if (method_call.method_name().compare("clearTemporaryFiles") == 0) {
            CleanupTempFiles();
            result->Success();
        }
        else {
            result->NotImplemented();
        }
    }

    void ImagePickerMasterPlugin::PickFiles(
            const flutter::EncodableMap& arguments,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        // Parse arguments
        std::string file_type = "all";
        bool allow_multiple = false;
        std::vector<std::string> allowed_extensions;
        bool with_data = false;
        bool allow_compression = false;
        int compression_quality = 80;

        auto type_it = arguments.find(flutter::EncodableValue("type"));
        if (type_it != arguments.end()) {
            if (const auto* type_str = std::get_if<std::string>(&type_it->second)) {
                file_type = *type_str;
            }
        }

        auto multiple_it = arguments.find(flutter::EncodableValue("allowMultiple"));
        if (multiple_it != arguments.end()) {
            if (const auto* multiple_bool = std::get_if<bool>(&multiple_it->second)) {
                allow_multiple = *multiple_bool;
            }
        }

        auto extensions_it = arguments.find(flutter::EncodableValue("allowedExtensions"));
        if (extensions_it != arguments.end()) {
            if (const auto* extensions_list = std::get_if<flutter::EncodableList>(&extensions_it->second)) {
                for (const auto& ext : *extensions_list) {
                    if (const auto* ext_str = std::get_if<std::string>(&ext)) {
                        allowed_extensions.push_back(*ext_str);
                    }
                }
            }
        }

        auto with_data_it = arguments.find(flutter::EncodableValue("withData"));
        if (with_data_it != arguments.end()) {
            if (const auto* with_data_bool = std::get_if<bool>(&with_data_it->second)) {
                with_data = *with_data_bool;
            }
        }

        auto compression_it = arguments.find(flutter::EncodableValue("allowCompression"));
        if (compression_it != arguments.end()) {
            if (const auto* compression_bool = std::get_if<bool>(&compression_it->second)) {
                allow_compression = *compression_bool;
            }
        }

        auto quality_it = arguments.find(flutter::EncodableValue("compressionQuality"));
        if (quality_it != arguments.end()) {
            if (const auto* quality_int = std::get_if<int>(&quality_it->second)) {
                compression_quality = *quality_int;
            }
        }

        // Show file picker
        ShowFilePicker(file_type, allow_multiple, allowed_extensions, with_data,
                       allow_compression, compression_quality, std::move(result));
    }

    void ImagePickerMasterPlugin::ShowFilePicker(
            const std::string& file_type,
            bool allow_multiple,
            const std::vector<std::string>& allowed_extensions,
            bool with_data,
            bool allow_compression,
            int compression_quality,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        IFileOpenDialog* pFileOpen;
        HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, NULL, CLSCTX_ALL,
                                      IID_IFileOpenDialog, reinterpret_cast<void**>(&pFileOpen));
        
        if (SUCCEEDED(hr)) {
            // Set options
            DWORD dwFlags;
            hr = pFileOpen->GetOptions(&dwFlags);
            if (SUCCEEDED(hr)) {
                dwFlags |= FOS_FORCEFILESYSTEM;
                if (allow_multiple) {
                    dwFlags |= FOS_ALLOWMULTISELECT;
                }
                hr = pFileOpen->SetOptions(dwFlags);
            }

            // Set file type filters
            std::vector<COMDLG_FILTERSPEC> filterSpecs = CreateFileFilters(file_type, allowed_extensions);
            if (!filterSpecs.empty()) {
                hr = pFileOpen->SetFileTypes(static_cast<UINT>(filterSpecs.size()), filterSpecs.data());
            }

            // Show the dialog
            hr = pFileOpen->Show(GetActiveWindow());
            
            if (SUCCEEDED(hr)) {
                // Get the results
                if (allow_multiple) {
                    IShellItemArray* pItems;
                    hr = pFileOpen->GetResults(&pItems);
                    if (SUCCEEDED(hr)) {
                        ProcessSelectedFiles(pItems, with_data, allow_compression, compression_quality, std::move(result));
                        pItems->Release();
                    } else {
                        result->Error("GET_RESULTS_ERROR", "Failed to get selected files");
                    }
                } else {
                    IShellItem* pItem;
                    hr = pFileOpen->GetResult(&pItem);
                    if (SUCCEEDED(hr)) {
                        ProcessSelectedFile(pItem, with_data, allow_compression, compression_quality, std::move(result));
                        pItem->Release();
                    } else {
                        result->Error("GET_RESULT_ERROR", "Failed to get selected file");
                    }
                }
            } else {
                result->Success(); // User cancelled
            }
            pFileOpen->Release();
        } else {
            result->Error("FILE_PICKER_ERROR", "Failed to create file picker");
        }
    }

    std::vector<COMDLG_FILTERSPEC> ImagePickerMasterPlugin::CreateFileFilters(
            const std::string& file_type,
            const std::vector<std::string>& allowed_extensions) {
        std::vector<COMDLG_FILTERSPEC> filters;

        if (file_type == "image") {
            static const wchar_t* imageFilter = L"*.jpg;*.jpeg;*.png;*.gif;*.bmp;*.tiff;*.webp";
            filters.push_back({L"Image Files", imageFilter});
        }
        else if (file_type == "video") {
            static const wchar_t* videoFilter = L"*.mp4;*.avi;*.mkv;*.mov;*.wmv;*.flv;*.webm";
            filters.push_back({L"Video Files", videoFilter});
        }
        else if (file_type == "audio") {
            static const wchar_t* audioFilter = L"*.mp3;*.wav;*.aiff;*.m4a;*.flac;*.ogg";
            filters.push_back({L"Audio Files", audioFilter});
        }
        else if (file_type == "document") {
            static const wchar_t* docFilter = L"*.pdf;*.doc;*.docx;*.xls;*.xlsx;*.ppt;*.pptx;*.txt;*.rtf;*.md;*.markdown;*.odt;*.ods;*.odp;*.html;*.htm;*.css;*.js;*.json;*.xml;*.csv;*.zip;*.rar;*.7z;*.tar;*.gz;*.php;*.py;*.c;*.cpp;*.java;*.sh;*.pl;*.rb;*.lua;*.yaml;*.yml;*.epub;*.ttf;*.otf;*.woff;*.woff2";
            filters.push_back({L"Document Files", docFilter});
        }
        else if (file_type == "custom" && !allowed_extensions.empty()) {
            // Build custom filter string
            std::wstring filterStr;
            for (size_t i = 0; i < allowed_extensions.size(); ++i) {
                if (i > 0) filterStr += L";";
                filterStr += L"*.";
                std::string ext = allowed_extensions[i];
                filterStr += std::wstring(ext.begin(), ext.end());
            }
            // Note: This is a simplified approach. In production, you'd want to
            // properly manage the memory for these wide strings.
            static std::wstring customFilter = filterStr;
            filters.push_back({L"Custom Files", customFilter.c_str()});
        }
        else {
            // All files
            static const wchar_t* allFilter = L"*.*";
            filters.push_back({L"All Files", allFilter});
        }

        return filters;
    }

    void ImagePickerMasterPlugin::ProcessSelectedFiles(
            IShellItemArray* pItems,
            bool with_data,
            bool allow_compression,
            int compression_quality,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        DWORD itemCount;
        HRESULT hr = pItems->GetCount(&itemCount);
        
        if (SUCCEEDED(hr)) {
            flutter::EncodableList fileList;
            for (DWORD i = 0; i < itemCount; ++i) {
                IShellItem* pItem;
                hr = pItems->GetItemAt(i, &pItem);
                if (SUCCEEDED(hr)) {
                    auto fileData = ProcessFileItem(pItem, with_data, allow_compression, compression_quality);
                    if (fileData.has_value()) {
                        fileList.push_back(fileData.value());
                    }
                    pItem->Release();
                }
            }
            
            if (!fileList.empty()) {
                result->Success(flutter::EncodableValue(fileList));
            } else {
                result->Success();
            }
        } else {
            result->Error("PROCESSING_ERROR", "Failed to process selected files");
        }
    }

    void ImagePickerMasterPlugin::ProcessSelectedFile(
            IShellItem* pItem,
            bool with_data,
            bool allow_compression,
            int compression_quality,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        auto fileData = ProcessFileItem(pItem, with_data, allow_compression, compression_quality);
        if (fileData.has_value()) {
            flutter::EncodableList fileList;
            fileList.push_back(fileData.value());
            result->Success(flutter::EncodableValue(fileList));
        } else {
            result->Success();
        }
    }

    std::optional<flutter::EncodableValue> ImagePickerMasterPlugin::ProcessFileItem(
            IShellItem* pItem,
            bool with_data,
            bool allow_compression,
            int compression_quality) {
        PWSTR pszFilePath;
        HRESULT hr = pItem->GetDisplayName(SIGDN_FILESYSPATH, &pszFilePath);
        if (SUCCEEDED(hr)) {
            std::wstring wFilePath(pszFilePath);
            
            // Proper Unicode conversion from wide string to UTF-8
            int utf8Length = WideCharToMultiByte(CP_UTF8, 0, wFilePath.c_str(), -1, nullptr, 0, nullptr, nullptr);
            std::string filePath(utf8Length - 1, '\0');
            WideCharToMultiByte(CP_UTF8, 0, wFilePath.c_str(), -1, &filePath[0], utf8Length, nullptr, nullptr);
            
            CoTaskMemFree(pszFilePath);

            try {
                fs::path path(wFilePath);
                std::wstring wFileName = path.filename().wstring();
                
                // Proper Unicode conversion for filename with error checking
                int fileNameUtf8Length = WideCharToMultiByte(CP_UTF8, 0, wFileName.c_str(), -1, nullptr, 0, nullptr, nullptr);
                if (fileNameUtf8Length <= 0) {
                    return std::nullopt;
                }
                
                std::string fileName(fileNameUtf8Length - 1, '\0');
                int result = WideCharToMultiByte(CP_UTF8, 0, wFileName.c_str(), -1, &fileName[0], fileNameUtf8Length, nullptr, nullptr);
                if (result == 0) {
                    return std::nullopt;
                }
                
                std::uintmax_t fileSize;
                try {
                    fileSize = fs::file_size(path);
                } catch (const fs::filesystem_error& e) {
                    return std::nullopt;
                }
                
                std::string mimeType;
                try {
                    mimeType = GetMimeType(path.extension().string());
                } catch (const std::exception& e) {
                    mimeType = "application/octet-stream";
                }

                // Use original file path instead of copying to temp location
                flutter::EncodableMap fileData;
                fileData[flutter::EncodableValue("path")] = flutter::EncodableValue(filePath);
                fileData[flutter::EncodableValue("name")] = flutter::EncodableValue(fileName);
                fileData[flutter::EncodableValue("size")] = flutter::EncodableValue(static_cast<int64_t>(fileSize));
                fileData[flutter::EncodableValue("mimeType")] = flutter::EncodableValue(mimeType);

                if (with_data) {
                    try {
                        std::vector<uint8_t> fileBytes = ReadFileBytes(filePath);

                        // Apply compression for images if requested
                        if (allow_compression && mimeType.find("image/") == 0) {
                            auto compressedPath = CompressImage(filePath, compression_quality);
                            if (compressedPath.has_value()) {
                                fileBytes = ReadFileBytes(compressedPath.value());
                            }
                        }

                        fileData[flutter::EncodableValue("bytes")] =
                                flutter::EncodableValue(flutter::EncodableList(fileBytes.begin(), fileBytes.end()));
                    } catch (const std::exception& e) {
                        // Continue without bytes data
                    }
                }

                return flutter::EncodableValue(fileData);
            } catch (const std::exception& e) {
                return std::nullopt;
            }
        }
        return std::nullopt;
    }

    std::string ImagePickerMasterPlugin::CreateTempFilePath(const std::string& extension) {
        // Get temp directory
        wchar_t tempPath[MAX_PATH];
        GetTempPathW(MAX_PATH, tempPath);
        fs::path tempDir = fs::path(tempPath) / TEMP_DIR_PREFIX;
        fs::create_directories(tempDir);

        // Generate unique filename
        std::string uniqueName = GenerateUUID() + extension;
        fs::path tempFilePath = tempDir / uniqueName;

        // Store for cleanup
        temporary_files_.push_back(tempFilePath.string());

        return tempFilePath.string();
    }

    std::vector<uint8_t> ImagePickerMasterPlugin::ReadFileBytes(const std::string& filePath) {
        // Convert UTF-8 string back to wide string for file operations
        int wideLength = MultiByteToWideChar(CP_UTF8, 0, filePath.c_str(), -1, nullptr, 0);
        std::wstring wFilePath(wideLength - 1, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, filePath.c_str(), -1, &wFilePath[0], wideLength);
        
        std::ifstream file(wFilePath, std::ios::binary);
        std::vector<uint8_t> bytes;
        if (file) {
            file.seekg(0, std::ios::end);
            size_t fileSize = file.tellg();
            file.seekg(0, std::ios::beg);
            bytes.resize(fileSize);
            file.read(reinterpret_cast<char*>(bytes.data()), fileSize);
        }
        return bytes;
    }

    std::optional<std::string> ImagePickerMasterPlugin::CompressImage(
            const std::string& file_path,
            int quality) {
        // Convert UTF-8 to wide string for file operations
        int wideLength = MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, nullptr, 0);
        std::wstring wFilePath(wideLength - 1, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, &wFilePath[0], wideLength);
        
        // This is a simplified implementation. In production, you'd want more robust image processing.
        // For now, return the original file path
        return file_path;
    }

    std::string ImagePickerMasterPlugin::GetMimeType(const std::string& extension) {
        static const std::map<std::string, std::string> mimeTypes = {
                // Images
                {".jpg", "image/jpeg"}, {".jpeg", "image/jpeg"}, {".png", "image/png"},
                {".gif", "image/gif"}, {".bmp", "image/bmp"}, {".tiff", "image/tiff"},
                {".webp", "image/webp"}, {".svg", "image/svg+xml"}, {".ico", "image/x-icon"},
                {".heic", "image/heic"}, {".heif", "image/heif"}, {".avif", "image/avif"},
                
                // Videos
                {".mp4", "video/mp4"}, {".avi", "video/x-msvideo"}, {".mov", "video/quicktime"},
                {".mkv", "video/x-matroska"}, {".wmv", "video/x-ms-wmv"}, {".flv", "video/x-flv"},
                {".webm", "video/webm"}, {".3gp", "video/3gpp"}, {".3g2", "video/3gpp2"},
                
                // Audio
                {".mp3", "audio/mpeg"}, {".wav", "audio/wav"}, {".m4a", "audio/mp4"},
                {".flac", "audio/flac"}, {".ogg", "audio/ogg"}, {".aac", "audio/aac"},
                {".midi", "audio/midi"}, {".opus", "audio/opus"}, {".aiff", "audio/x-aiff"},
                
                // Documents - PDF
                {".pdf", "application/pdf"},
                
                // Documents - Microsoft Office
                {".doc", "application/msword"},
                {".docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"},
                {".xls", "application/vnd.ms-excel"},
                {".xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"},
                {".ppt", "application/vnd.ms-powerpoint"},
                {".pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation"},
                
                // Documents - Text
                {".txt", "text/plain"}, {".rtf", "text/rtf"}, {".md", "text/markdown"}, 
                {".markdown", "text/markdown"},
                
                // Documents - OpenDocument
                {".odt", "application/vnd.oasis.opendocument.text"},
                {".ods", "application/vnd.oasis.opendocument.spreadsheet"},
                {".odp", "application/vnd.oasis.opendocument.presentation"},
                
                // Documents - Web
                {".html", "text/html"}, {".htm", "text/html"}, {".css", "text/css"},
                {".js", "text/javascript"}, {".json", "application/json"}, {".xml", "application/xml"},
                {".csv", "text/csv"}, {".yaml", "text/yaml"}, {".yml", "text/yaml"},
                
                // Documents - Code
                {".php", "application/x-httpd-php"}, {".py", "text/x-python"},
                {".c", "text/x-c"}, {".cpp", "text/x-c++"}, {".java", "text/x-java-source"},
                {".sh", "application/x-sh"}, {".pl", "text/x-perl"}, {".rb", "text/x-ruby"},
                {".lua", "text/x-lua"},
                
                // Archives
                {".zip", "application/zip"}, {".rar", "application/x-rar-compressed"},
                {".7z", "application/x-7z-compressed"}, {".tar", "application/x-tar"},
                {".gz", "application/gzip"}, {".bz2", "application/x-bzip2"},
                
                // Fonts
                {".ttf", "font/ttf"}, {".otf", "font/otf"}, {".woff", "font/woff"},
                {".woff2", "font/woff2"},
                
                // Other
                {".epub", "application/epub+zip"}
        };
        
        // Convert extension to lowercase for comparison
        std::string lowerExt = extension;
        std::transform(lowerExt.begin(), lowerExt.end(), lowerExt.begin(), ::tolower);
        
        auto it = mimeTypes.find(lowerExt);
        return (it != mimeTypes.end()) ? it->second : "application/octet-stream";
    }

    std::string ImagePickerMasterPlugin::GenerateUUID() {
        // Simple UUID generation - in production use proper UUID library
        GUID guid;
        CoCreateGuid(&guid);
        char guidStr[40];
        sprintf_s(guidStr, "%08X-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                  guid.Data1, guid.Data2, guid.Data3,
                  guid.Data4[0], guid.Data4[1], guid.Data4[2], guid.Data4[3],
                  guid.Data4[4], guid.Data4[5], guid.Data4[6], guid.Data4[7]);
        return std::string(guidStr);
    }

    void ImagePickerMasterPlugin::CleanupTempFiles() {
        for (const auto& filePath : temporary_files_) {
            try {
                fs::remove(filePath);
            } catch (const std::exception& e) {
                // Ignore cleanup errors
            }
        }
        temporary_files_.clear();
    }

    bool ImagePickerMasterPlugin::IsImageFile(const std::string& file_path) {
        std::string ext = GetFileExtension(file_path);
        std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);

        return ext == ".jpg" || ext == ".jpeg" || ext == ".png" ||
               ext == ".gif" || ext == ".bmp" || ext == ".tiff" || ext == ".webp";
    }

    std::string ImagePickerMasterPlugin::GetFileExtension(const std::string& file_path) {
        // Convert UTF-8 to wide string for filesystem operations
        int wideLength = MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, nullptr, 0);
        std::wstring wFilePath(wideLength - 1, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, &wFilePath[0], wideLength);
        
        fs::path path(wFilePath);
        std::wstring wExtension = path.extension().wstring();
        
        // Convert extension back to UTF-8
        int extUtf8Length = WideCharToMultiByte(CP_UTF8, 0, wExtension.c_str(), -1, nullptr, 0, nullptr, nullptr);
        std::string extension(extUtf8Length - 1, '\0');
        WideCharToMultiByte(CP_UTF8, 0, wExtension.c_str(), -1, &extension[0], extUtf8Length, nullptr, nullptr);
        
        return extension;
    }

    std::optional<std::string> ImagePickerMasterPlugin::ReadFileAsBase64(const std::string& file_path) {
        // Convert UTF-8 to wide string for file operations
        int wideLength = MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, nullptr, 0);
        std::wstring wFilePath(wideLength - 1, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, file_path.c_str(), -1, &wFilePath[0], wideLength);
        
        std::vector<uint8_t> bytes = ReadFileBytes(file_path);
        if (bytes.empty()) {
            return std::nullopt;
        }

        // Simple base64 encoding - in production use proper base64 library
        static const std::string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        std::string result;
        int val = 0, valb = -6;
        for (uint8_t c : bytes) {
            val = (val << 8) + c;
            valb += 8;
            while (valb >= 0) {
                result.push_back(chars[(val >> valb) & 0x3F]);
                valb -= 6;
            }
        }

        if (valb > -6) result.push_back(chars[((val << 8) >> (valb + 8)) & 0x3F]);
        while (result.size() % 4) result.push_back('=');

        return result;
    }

    bool ImagePickerMasterPlugin::ConvertToJpeg(
            const std::string& input_path,
            const std::string& output_path,
            int quality) {
        // Convert UTF-8 strings to wide strings for GDI+ operations
        int inputWideLength = MultiByteToWideChar(CP_UTF8, 0, input_path.c_str(), -1, nullptr, 0);
        std::wstring wInputPath(inputWideLength - 1, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, input_path.c_str(), -1, &wInputPath[0], inputWideLength);
        
        int outputWideLength = MultiByteToWideChar(CP_UTF8, 0, output_path.c_str(), -1, nullptr, 0);
        std::wstring wOutputPath(outputWideLength - 1, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, output_path.c_str(), -1, &wOutputPath[0], outputWideLength);

        Bitmap* bitmap = new Bitmap(wInputPath.c_str());
        if (bitmap->GetLastStatus() != Ok) {
            delete bitmap;
            return false;
        }

        CLSID jpegClsid;
        if (!GetImageEncoder(L"image/jpeg", &jpegClsid)) {
            delete bitmap;
            return false;
        }

        EncoderParameters encoderParams;
        encoderParams.Count = 1;
        encoderParams.Parameter[0].Guid = EncoderQuality;
        encoderParams.Parameter[0].Type = EncoderParameterValueTypeLong;
        encoderParams.Parameter[0].NumberOfValues = 1;
        ULONG qualityValue = quality;
        encoderParams.Parameter[0].Value = &qualityValue;

        Status status = bitmap->Save(wOutputPath.c_str(), &jpegClsid, &encoderParams);
        delete bitmap;

        return status == Ok;
    }

    bool ImagePickerMasterPlugin::GetImageEncoder(
            const std::wstring& format,
            CLSID* pClsid) {
        UINT num = 0;
        UINT size = 0;
        GetImageEncodersSize(&num, &size);
        if (size == 0) return false;

        ImageCodecInfo* pImageCodecInfo = (ImageCodecInfo*)(malloc(size));
        if (pImageCodecInfo == NULL) return false;

        GetImageEncoders(num, size, pImageCodecInfo);
        for (UINT j = 0; j < num; ++j) {
            if (wcscmp(pImageCodecInfo[j].MimeType, format.c_str()) == 0) {
                *pClsid = pImageCodecInfo[j].Clsid;
                free(pImageCodecInfo);
                return true;
            }
        }

        free(pImageCodecInfo);
        return false;
    }

    void ImagePickerMasterPlugin::SendError(
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
            const std::string& error_code,
            const std::string& error_message) {
        result->Error(error_code, error_message);
    }

}  // namespace image_picker_master