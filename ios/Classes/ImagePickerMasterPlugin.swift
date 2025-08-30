import Flutter
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
import AVFoundation
import Photos

public class ImagePickerMasterPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var result: FlutterResult?
    private var allowMultiple = false
    private var fileType = "all"
    private var allowedExtensions: [String]?
    private var withData = false
    private var allowCompression = false
    private var compressionQuality: CGFloat = 0.8
    private var temporaryFiles: [URL] = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "image_picker_master", binaryMessenger: registrar.messenger())
        let instance = ImagePickerMasterPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.result = result

        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "pickFiles":
            guard let arguments = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                return
            }
            pickFiles(arguments: arguments)

        case "clearTemporaryFiles":
            clearTemporaryFiles()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func pickFiles(arguments: [String: Any]) {
        fileType = arguments["type"] as? String ?? "all"
        allowMultiple = arguments["allowMultiple"] as? Bool ?? false
        allowedExtensions = arguments["allowedExtensions"] as? [String]
        withData = arguments["withData"] as? Bool ?? false
        allowCompression = arguments["allowCompression"] as? Bool ?? false

        if let quality = arguments["compressionQuality"] as? Int {
            compressionQuality = CGFloat(quality) / 100.0
        }

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result?(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Cannot find view controller", details: nil))
            return
        }

        let alertController = UIAlertController(title: "Select Source", message: nil, preferredStyle: .actionSheet)

        // Add document picker option
        alertController.addAction(UIAlertAction(title: "Browse Files", style: .default) { _ in
            self.presentDocumentPicker(from: viewController)
        })

        // Add camera options for images and videos
        if fileType == "image" || fileType == "all" {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                alertController.addAction(UIAlertAction(title: "Take Photo", style: .default) { _ in
                    self.presentImagePicker(sourceType: .camera, from: viewController)
                })
            }
        }

        if fileType == "video" || fileType == "all" {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                alertController.addAction(UIAlertAction(title: "Record Video", style: .default) { _ in
                    self.presentVideoPicker(sourceType: .camera, from: viewController)
                })
            }
        }

        // Add photo library option
        if fileType == "image" || fileType == "video" || fileType == "all" {
            alertController.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
                if self.fileType == "image" {
                    self.presentImagePicker(sourceType: .photoLibrary, from: viewController)
                } else if self.fileType == "video" {
                    self.presentVideoPicker(sourceType: .photoLibrary, from: viewController)
                } else {
                    self.presentImagePicker(sourceType: .photoLibrary, from: viewController)
                }
            })
        }

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.result?(nil)
        })

        // For iPad
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        viewController.present(alertController, animated: true)
    }

    @available(iOS 14.0, *)
    private func presentDocumentPicker(from viewController: UIViewController) {
        var contentTypes: [UTType] = []

        switch fileType {
        case "image":
            contentTypes = [.image, .jpeg, .png, .gif, .bmp, .tiff]
        case "video":
            contentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        case "audio":
            contentTypes = [.audio, .mp3, .wav, .aiff, .m4a]
        case "document":
            contentTypes = [
                // PDF
                .pdf,
                
                // Microsoft Office - Word
                .doc, .docx,
                
                // Microsoft Office - Excel
                .xls, .xlsx,
                
                // Microsoft Office - PowerPoint
                .ppt, .pptx,
                
                // Text files
                .text, .plainText, .rtf,
                
                // OpenDocument formats
                UTType("org.oasis-open.opendocument.text")!,
                UTType("org.oasis-open.opendocument.spreadsheet")!,
                UTType("org.oasis-open.opendocument.presentation")!,
                
                // Archive formats
                .zip, .gzip,
                UTType("com.rarlab.rar-archive")!,
                UTType("org.7-zip.7-zip-archive")!,
                
                // Code files
                .html, .css, .javascript, .json, .xml, .yaml,
                UTType("public.php-script")!,
                UTType("public.python-script")!,
                UTType("public.c-source")!,
                UTType("public.c-plus-plus-source")!,
                UTType("com.sun.java-source")!,
                UTType("public.shell-script")!,
                UTType("public.perl-script")!,
                UTType("public.ruby-script")!,
                
                // Image formats
                .image, .jpeg, .png, .gif, .bmp, .tiff, .svg, .webP, .ico, .heic, .heif,
                
                // Audio formats
                .audio, .mp3, .wav, .aiff, .m4a, .flac, .ogg,
                
                // Video formats
                .movie, .video, .mpeg4Movie, .quickTimeMovie, .avi,
                
                // Font formats
                UTType("public.truetype-ttf-font")!,
                UTType("public.opentype-font")!,
                
                // Other formats
                .data, .epub
            ]
        case "custom":
            if let extensions = allowedExtensions {
                contentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
            }
            if contentTypes.isEmpty {
                contentTypes = [.data]
            }
        default:
            contentTypes = [.data]
        }

        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = allowMultiple
        documentPicker.modalPresentationStyle = .formSheet

        viewController.present(documentPicker, animated: true)
    }

    private func presentImagePicker(sourceType: UIImagePickerController.SourceType, from viewController: UIViewController) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            result?(FlutterError(code: "SOURCE_NOT_AVAILABLE", message: "Source type not available", details: nil))
            return
        }

        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = sourceType
        imagePicker.mediaTypes = [kUTTypeImage as String]
        imagePicker.delegate = self
        imagePicker.allowsEditing = false

        viewController.present(imagePicker, animated: true)
    }

    private func presentVideoPicker(sourceType: UIImagePickerController.SourceType, from viewController: UIViewController) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            result?(FlutterError(code: "SOURCE_NOT_AVAILABLE", message: "Source type not available", details: nil))
            return
        }

        let videoPicker = UIImagePickerController()
        videoPicker.sourceType = sourceType
        videoPicker.mediaTypes = [kUTTypeMovie as String]
        videoPicker.delegate = self
        videoPicker.allowsEditing = false
        videoPicker.videoQuality = .typeMedium

        viewController.present(videoPicker, animated: true)
    }

    private func processFile(url: URL) -> [String: Any]? {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey, .typeIdentifierKey, .localizedNameKey])
            let fileName = resources.localizedName ?? url.lastPathComponent
            let fileSize = resources.fileSize ?? 0
            let mimeType = getMimeType(from: resources.typeIdentifier)

            // Copy to temporary location
            let tempURL = createTemporaryFile(from: url, fileName: fileName)

            var fileData: [String: Any] = [
                "path": tempURL.path,
                "name": fileName,
                "size": fileSize,
                "mimeType": mimeType ?? ""
            ]

            if withData {
                var data = try Data(contentsOf: url)

                // Apply compression for images
                if allowCompression, let mimeType = mimeType, mimeType.hasPrefix("image/") {
                    data = compressImageData(data) ?? data
                }

                fileData["bytes"] = FlutterStandardTypedData(bytes: data)
            }

            return fileData
        } catch {
            return nil
        }
    }

    private func createTemporaryFile(from sourceURL: URL, fileName: String) -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("file_picker")

        if !FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        }

        let tempURL = tempDirectory.appendingPathComponent("\(UUID().uuidString)_\(fileName)")
        temporaryFiles.append(tempURL)

        try? FileManager.default.copyItem(at: sourceURL, to: tempURL)

        return tempURL
    }

    private func getMimeType(from typeIdentifier: String?) -> String? {
        guard let typeIdentifier = typeIdentifier else { return nil }

        if #available(iOS 14.0, *) {
            return UTType(typeIdentifier)?.preferredMIMEType
        } else {
            return UTTypeCopyPreferredTagWithClass(typeIdentifier as CFString, kUTTagClassMIMEType)?.takeRetainedValue() as String?
        }
    }

    private func compressImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: compressionQuality)
    }

    private func clearTemporaryFiles() {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
    }
}

// MARK: - UIDocumentPickerDelegate
extension ImagePickerMasterPlugin: UIDocumentPickerDelegate {
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var selectedFiles: [[String: Any]] = []

        for url in urls {
            if let fileData = processFile(url: url) {
                selectedFiles.append(fileData)
            }
        }

        result?(selectedFiles.isEmpty ? nil : selectedFiles)
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        result?(nil)
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension ImagePickerMasterPlugin: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)

        guard let mediaType = info[.mediaType] as? String else {
            result?(FlutterError(code: "NO_MEDIA_TYPE", message: "No media type found", details: nil))
            return
        }

        if mediaType == kUTTypeImage as String {
            handleImageSelection(info: info)
        } else if mediaType == kUTTypeMovie as String {
            handleVideoSelection(info: info)
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        result?(nil)
    }

    private func handleImageSelection(info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else {
            result?(FlutterError(code: "NO_IMAGE", message: "No image selected", details: nil))
            return
        }

        let fileName = "image_\(Date().timeIntervalSince1970).jpg"
        var imageData = image.jpegData(compressionQuality: allowCompression ? compressionQuality : 1.0) ?? Data()

        // Save to temporary file
        let tempURL = saveDataToTemporaryFile(data: imageData, fileName: fileName)

        var fileData: [String: Any] = [
            "path": tempURL.path,
            "name": fileName,
            "size": imageData.count,
            "mimeType": "image/jpeg"
        ]

        if withData {
            fileData["bytes"] = FlutterStandardTypedData(bytes: imageData)
        }

        result?([fileData])
    }

    private func handleVideoSelection(info: [UIImagePickerController.InfoKey : Any]) {
        guard let videoURL = info[.mediaURL] as? URL else {
            result?(FlutterError(code: "NO_VIDEO", message: "No video selected", details: nil))
            return
        }

        if let fileData = processFile(url: videoURL) {
            result?([fileData])
        } else {
            result?(FlutterError(code: "VIDEO_PROCESSING_ERROR", message: "Error processing video", details: nil))
        }
    }

    private func saveDataToTemporaryFile(data: Data, fileName: String) -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("file_picker")

        if !FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        }

        let tempURL = tempDirectory.appendingPathComponent("\(UUID().uuidString)_\(fileName)")
        temporaryFiles.append(tempURL)

        try? data.write(to: tempURL)

        return tempURL
    }
}