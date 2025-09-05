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
    // Track whether the current flow is capturePhoto (true) or pickFiles (false)
    private var isCapturePhotoMode = false

    // Scene-aware way to get the top-most view controller (iOS 13+ safe)
    private func getRootViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
            if let window = scenes.first?.windows.first(where: { $0.isKeyWindow }) ?? scenes.first?.windows.first {
                return window.rootViewController
            }
            return UIApplication.shared.windows.first?.rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }

    private func topMostViewController(base: UIViewController?) -> UIViewController? {
        guard let base = base else { return nil }
        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = base.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }

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

        case "capturePhoto":
            guard let arguments = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                return
            }
            capturePhoto(arguments: arguments)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func pickFiles(arguments: [String: Any]) {
        // Ensure we are not in capture mode for generic picking flows
        isCapturePhotoMode = false
        fileType = arguments["type"] as? String ?? "all"
        allowMultiple = arguments["allowMultiple"] as? Bool ?? false
        allowedExtensions = arguments["allowedExtensions"] as? [String]
        withData = arguments["withData"] as? Bool ?? false
        allowCompression = arguments["allowCompression"] as? Bool ?? false

        if let quality = arguments["compressionQuality"] as? Int {
            compressionQuality = CGFloat(quality) / 100.0
        }

        guard let viewController = topMostViewController(base: getRootViewController()) else {
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

    private func presentDocumentPicker(from viewController: UIViewController) {
        if #available(iOS 14.0, *) {
            presentModernDocumentPicker(from: viewController)
        } else {
            presentLegacyDocumentPicker(from: viewController)
        }
    }
    
    @available(iOS 14.0, *)
    private func presentModernDocumentPicker(from viewController: UIViewController) {
        var contentTypes: [UTType] = []

        switch fileType {
        case "image":
            contentTypes = [.image, .jpeg, .png, .gif, .bmp, .tiff]
        case "video":
            contentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        case "audio":
            contentTypes = [.audio, .mp3, .wav, .aiff, .m4a]
        case "document":
            contentTypes = getDocumentUTTypes()
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
    
    private func presentLegacyDocumentPicker(from viewController: UIViewController) {
        var documentTypes: [String] = []
        
        switch fileType {
        case "image":
            documentTypes = [kUTTypeImage as String]
        case "video":
            documentTypes = [kUTTypeMovie as String, kUTTypeVideo as String]
        case "audio":
            documentTypes = [kUTTypeAudio as String]
        case "document":
            documentTypes = getLegacyDocumentTypes()
        case "custom":
            if let extensions = allowedExtensions {
                // For legacy, we'll use common document types
                documentTypes = [kUTTypeData as String]
            } else {
                documentTypes = [kUTTypeData as String]
            }
        default:
            documentTypes = [kUTTypeData as String]
        }
        
        let documentPicker = UIDocumentPickerViewController(documentTypes: documentTypes, in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = allowMultiple
        documentPicker.modalPresentationStyle = .formSheet
        
        viewController.present(documentPicker, animated: true)
    }
    
    @available(iOS 14.0, *)
    private func getDocumentUTTypes() -> [UTType] {
        var contentTypes: [UTType] = []
        
        // PDF
        contentTypes.append(.pdf)
        
        // Microsoft Office - Word (using safe creation methods)
        if let docType = UTType("com.microsoft.word.doc") {
            contentTypes.append(docType)
        }
        if let docxType = UTType("org.openxmlformats.wordprocessingml.document") {
            contentTypes.append(docxType)
        }
        
        // Microsoft Office - Excel
        if let xlsType = UTType("com.microsoft.excel.xls") {
            contentTypes.append(xlsType)
        }
        if let xlsxType = UTType("org.openxmlformats.spreadsheetml.sheet") {
            contentTypes.append(xlsxType)
        }
        
        // Microsoft Office - PowerPoint
        if let pptType = UTType("com.microsoft.powerpoint.ppt") {
            contentTypes.append(pptType)
        }
        if let pptxType = UTType("org.openxmlformats.presentationml.presentation") {
            contentTypes.append(pptxType)
        }
        
        // Text files
        contentTypes.append(.text)
        contentTypes.append(.plainText)
        if let rtfType = UTType("public.rtf") {
            contentTypes.append(rtfType)
        }
        
        // OpenDocument formats
        if let odtType = UTType("org.oasis-open.opendocument.text") {
            contentTypes.append(odtType)
        }
        if let odsType = UTType("org.oasis-open.opendocument.spreadsheet") {
            contentTypes.append(odsType)
        }
        if let odpType = UTType("org.oasis-open.opendocument.presentation") {
            contentTypes.append(odpType)
        }
        
        // Archive formats
        contentTypes.append(.zip)
        contentTypes.append(.gzip)
        if let rarType = UTType("com.rarlab.rar-archive") {
            contentTypes.append(rarType)
        }
        if let sevenZipType = UTType("org.7-zip.7-zip-archive") {
            contentTypes.append(sevenZipType)
        }
        
        // Code files
        contentTypes.append(.html)
        if let cssType = UTType("public.css") {
            contentTypes.append(cssType)
        }
        contentTypes.append(.javascript)
        contentTypes.append(.json)
        contentTypes.append(.xml)
        if let yamlType = UTType("public.yaml") {
            contentTypes.append(yamlType)
        }
        
        // Programming language files
        if let phpType = UTType("public.php-script") {
            contentTypes.append(phpType)
        }
        if let pythonType = UTType("public.python-script") {
            contentTypes.append(pythonType)
        }
        if let cType = UTType("public.c-source") {
            contentTypes.append(cType)
        }
        if let cppType = UTType("public.c-plus-plus-source") {
            contentTypes.append(cppType)
        }
        if let javaType = UTType("com.sun.java-source") {
            contentTypes.append(javaType)
        }
        if let shellType = UTType("public.shell-script") {
            contentTypes.append(shellType)
        }
        
        // Image formats
        contentTypes.append(.image)
        contentTypes.append(.jpeg)
        contentTypes.append(.png)
        contentTypes.append(.gif)
        contentTypes.append(.bmp)
        contentTypes.append(.tiff)
        if let svgType = UTType("public.svg-image") {
            contentTypes.append(svgType)
        }
        if let webpType = UTType("org.webmproject.webp") {
            contentTypes.append(webpType)
        }
        if let icoType = UTType("com.microsoft.ico") {
            contentTypes.append(icoType)
        }
        contentTypes.append(.heic)
        contentTypes.append(.heif)
        
        // Audio formats
        contentTypes.append(.audio)
        contentTypes.append(.mp3)
        contentTypes.append(.wav)
        contentTypes.append(.aiff)
        contentTypes.append(.m4a)
        if let flacType = UTType("org.xiph.flac") {
            contentTypes.append(flacType)
        }
        if let oggType = UTType("org.xiph.ogg") {
            contentTypes.append(oggType)
        }
        
        // Video formats
        contentTypes.append(.movie)
        contentTypes.append(.video)
        contentTypes.append(.mpeg4Movie)
        contentTypes.append(.quickTimeMovie)
        contentTypes.append(.avi)
        
        // Font formats
        if let ttfType = UTType("public.truetype-ttf-font") {
            contentTypes.append(ttfType)
        }
        if let otfType = UTType("public.opentype-font") {
            contentTypes.append(otfType)
        }
        
        // Other formats
        contentTypes.append(.data)
        if let epubType = UTType("org.idpf.epub-container") {
            contentTypes.append(epubType)
        }
        
        return contentTypes
    }
    
    private func getLegacyDocumentTypes() -> [String] {
        return [
            // PDF
            kUTTypePDF as String,
            
            // Microsoft Office
            "com.microsoft.word.doc",
            "org.openxmlformats.wordprocessingml.document",
            "com.microsoft.excel.xls", 
            "org.openxmlformats.spreadsheetml.sheet",
            "com.microsoft.powerpoint.ppt",
            "org.openxmlformats.presentationml.presentation",
            
            // Text files
            kUTTypeText as String,
            kUTTypePlainText as String,
            kUTTypeRTF as String,
            
            // Archive formats
            kUTTypeZipArchive as String,
            kUTTypeGZIP as String,
            
            // Code files
            kUTTypeHTML as String,
            "public.css",
            "com.netscape.javascript-source",
            kUTTypeJSON as String,
            kUTTypeXML as String,
            
            // Images
            kUTTypeImage as String,
            kUTTypeJPEG as String,
            kUTTypePNG as String,
            kUTTypeGIF as String,
            kUTTypeBMP as String,
            kUTTypeTIFF as String,
            
            // Audio
            kUTTypeAudio as String,
            kUTTypeMP3 as String,
            
            // Video
            kUTTypeMovie as String,
            kUTTypeVideo as String,
            kUTTypeMPEG4 as String,
            kUTTypeQuickTimeMovie as String,
            
            // Generic data
            kUTTypeData as String
        ]
    }

    private func presentImagePicker(sourceType: UIImagePickerController.SourceType, from viewController: UIViewController) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            result?(FlutterError(code: "SOURCE_NOT_AVAILABLE", message: "Source type not available", details: nil))
            return
        }

        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = sourceType
        let mediaTypeImage: String
        if #available(iOS 14.0, *) {
            mediaTypeImage = UTType.image.identifier
        } else {
            mediaTypeImage = kUTTypeImage as String
        }
        imagePicker.mediaTypes = [mediaTypeImage]
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
        let mediaTypeMovie: String
        if #available(iOS 14.0, *) {
            mediaTypeMovie = UTType.movie.identifier
        } else {
            mediaTypeMovie = kUTTypeMovie as String
        }
        videoPicker.mediaTypes = [mediaTypeMovie]
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

    private func capturePhoto(arguments: [String: Any]) {
        // Mark that we are in capture photo mode to shape the result accordingly
        isCapturePhotoMode = true
        allowCompression = arguments["allowCompression"] as? Bool ?? false
        withData = arguments["withData"] as? Bool ?? false
        
        if let quality = arguments["compressionQuality"] as? Int {
            compressionQuality = CGFloat(quality) / 100.0
        }
        
        guard let viewController = topMostViewController(base: getRootViewController()) else {
            result?(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Cannot find view controller", details: nil))
            return
        }
        
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            result?(FlutterError(code: "CAMERA_NOT_AVAILABLE", message: "Camera not available", details: nil))
            return
        }
        
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        let mediaTypeImage: String
        if #available(iOS 14.0, *) {
            mediaTypeImage = UTType.image.identifier
        } else {
            mediaTypeImage = kUTTypeImage as String
        }
        imagePicker.mediaTypes = [mediaTypeImage]
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        
        viewController.present(imagePicker, animated: true)
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
        // Reset capture mode on cancel
        isCapturePhotoMode = false
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

        // If this image came from capturePhoto, return a single Map; otherwise, return a List for pickFiles
        if isCapturePhotoMode {
            result?(fileData)
        } else {
            result?([fileData])
        }
        // Reset the mode after handling
        isCapturePhotoMode = false
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
}