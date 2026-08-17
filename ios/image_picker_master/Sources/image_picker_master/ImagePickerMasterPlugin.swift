import Flutter
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

public class ImagePickerMasterPlugin: NSObject, FlutterPlugin {

    // ─── Channel ──────────────────────────────────────────────────────────
    private var channel: FlutterMethodChannel?

    // ─── Per-call state (reset on every method call) ──────────────────────
    // Keeping call state here (not as loose ivars) prevents state bleeding
    // between sequential calls.
    private var pendingCall: PendingCall?

    /// Wraps one in-flight method call's result + options.
    /// Using a class so it can be captured by reference in closures.
    private class PendingCall {
        let result: FlutterResult
        var allowMultiple:      Bool     = false
        var fileType:           String   = "all"
        var allowedExtensions:  [String]?
        var withData:           Bool     = false
        var allowCompression:   Bool     = false
        var compressionQuality: CGFloat  = 0.8
        var isCapturePhotoMode: Bool     = false
        var temporaryFiles:     [URL]    = []   // per-call temp files (plugin-wide cleanup also exists)

        private var consumed = false

        init(_ result: @escaping FlutterResult) { self.result = result }

        /// Call result exactly once; subsequent calls are no-ops.
        func send(_ value: Any?) {
            guard !consumed else { return }
            consumed = true
            result(value)
        }

        func sendError(_ code: String, _ message: String, _ details: Any? = nil) {
            guard !consumed else { return }
            consumed = true
            result(FlutterError(code: code, message: message, details: details))
        }
    }

    // Plugin-wide temporary files (for clearTemporaryFiles across calls)
    private var allTemporaryFiles: [URL] = []

    // ─── Registration ─────────────────────────────────────────────────────

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "image_picker_master",
            binaryMessenger: registrar.messenger())
        let instance = ImagePickerMasterPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // ─── Method dispatch ──────────────────────────────────────────────────

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "pickFiles":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                    message: "Arguments must be a map", details: nil))
                return
            }
            let pending = PendingCall(result)
            pendingCall = pending
            pickFiles(arguments: args, pending: pending)

        case "capturePhoto":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                    message: "Arguments must be a map", details: nil))
                return
            }
            let pending = PendingCall(result)
            pendingCall = pending
            capturePhoto(arguments: args, pending: pending)

        case "clearTemporaryFiles":
            clearAllTemporaryFiles()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ─── View controller helpers ──────────────────────────────────────────

    private func getRootViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
            if let window = scenes.first?.windows.first(where: { $0.isKeyWindow })
                            ?? scenes.first?.windows.first {
                return window.rootViewController
            }
        }
        return UIApplication.shared.keyWindow?.rootViewController
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

    // ─── pickFiles ────────────────────────────────────────────────────────

    private func pickFiles(arguments: [String: Any], pending: PendingCall) {
        pending.isCapturePhotoMode = false
        pending.fileType           = arguments["type"]             as? String ?? "all"
        pending.allowMultiple      = arguments["allowMultiple"]    as? Bool   ?? false
        pending.allowedExtensions  = arguments["allowedExtensions"] as? [String]
        pending.withData           = arguments["withData"]          as? Bool   ?? false
        pending.allowCompression   = arguments["allowCompression"]  as? Bool   ?? false
        // Reset to default before optional override to prevent bleed between calls
        pending.compressionQuality = 0.8
        if let q = arguments["compressionQuality"] as? Int {
            pending.compressionQuality = CGFloat(q) / 100.0
        }

        guard let vc = topMostViewController(base: getRootViewController()) else {
            pending.sendError("NO_VIEW_CONTROLLER", "Cannot find view controller")
            return
        }

        let alert = UIAlertController(
            title: "Select Source", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Browse Files", style: .default) { [weak self] _ in
            self?.presentDocumentPicker(from: vc, pending: pending)
        })

        if pending.fileType == "image" || pending.fileType == "all" {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                alert.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                    self?.presentImagePicker(sourceType: .camera, from: vc, pending: pending)
                })
            }
        }

        if pending.fileType == "video" || pending.fileType == "all" {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                alert.addAction(UIAlertAction(title: "Record Video", style: .default) { [weak self] _ in
                    self?.presentVideoPicker(sourceType: .camera, from: vc, pending: pending)
                })
            }
        }

        if pending.fileType == "image" || pending.fileType == "video" || pending.fileType == "all" {
            alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
                guard let self = self else { return }
                if pending.fileType == "video" {
                    self.presentVideoPicker(sourceType: .photoLibrary, from: vc, pending: pending)
                } else {
                    self.presentImagePicker(sourceType: .photoLibrary, from: vc, pending: pending)
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            pending.send(nil)
        })

        // iPad: set source so the popover has an anchor
        if let pop = alert.popoverPresentationController {
            pop.sourceView = vc.view
            pop.sourceRect = CGRect(
                x: vc.view.bounds.midX, y: vc.view.bounds.midY,
                width: 0, height: 0)
            pop.permittedArrowDirections = []
            // Catch iPad tap-outside-popover dismissal (= user cancel)
            pop.delegate = AlertDismissProxy(onDismiss: { pending.send(nil) })
        }

        vc.present(alert, animated: true)
    }

    // ─── capturePhoto ─────────────────────────────────────────────────────

    private func capturePhoto(arguments: [String: Any], pending: PendingCall) {
        pending.isCapturePhotoMode = true
        pending.allowCompression   = arguments["allowCompression"]  as? Bool ?? false
        pending.withData           = arguments["withData"]          as? Bool ?? false
        // Reset before optional override
        pending.compressionQuality = 0.8
        if let q = arguments["compressionQuality"] as? Int {
            pending.compressionQuality = CGFloat(q) / 100.0
        }

        guard let vc = topMostViewController(base: getRootViewController()) else {
            pending.isCapturePhotoMode = false
            pending.sendError("NO_VIEW_CONTROLLER", "Cannot find view controller")
            return
        }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            pending.isCapturePhotoMode = false
            pending.sendError("CAMERA_NOT_AVAILABLE", "Camera is not available on this device")
            return
        }

        presentImagePicker(sourceType: .camera, from: vc, pending: pending)
    }

    // ─── Document picker ──────────────────────────────────────────────────

    private func presentDocumentPicker(from vc: UIViewController, pending: PendingCall) {
        if #available(iOS 14.0, *) {
            presentModernDocumentPicker(from: vc, pending: pending)
        } else {
            presentLegacyDocumentPicker(from: vc, pending: pending)
        }
    }

    @available(iOS 14.0, *)
    private func presentModernDocumentPicker(from vc: UIViewController, pending: PendingCall) {
        var contentTypes: [UTType] = []

        switch pending.fileType {
        case "image":
            contentTypes = [.image, .jpeg, .png, .gif, .bmp, .tiff, .heic, .heif]
            if let webp = UTType("org.webmproject.webp") { contentTypes.append(webp) }
        case "video":
            contentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        case "audio":
            contentTypes = [.audio, .mp3, .wav, .aiff, .m4a]
            if let flac = UTType("org.xiph.flac") { contentTypes.append(flac) }
        case "document":
            contentTypes = documentUTTypes()
        case "custom":
            if let exts = pending.allowedExtensions, !exts.isEmpty {
                contentTypes = exts.compactMap { UTType(filenameExtension: $0) }
            }
            if contentTypes.isEmpty { contentTypes = [.data] }
        default: // "all"
            contentTypes = [.data]
        }

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = DocumentPickerDelegate(pending: pending)
        picker.allowsMultipleSelection = pending.allowMultiple
        picker.modalPresentationStyle = .formSheet
        vc.present(picker, animated: true)
    }

    private func presentLegacyDocumentPicker(from vc: UIViewController, pending: PendingCall) {
        var documentTypes: [String]

        switch pending.fileType {
        case "image":
            documentTypes = [kUTTypeImage as String]
        case "video":
            documentTypes = [kUTTypeMovie as String, kUTTypeVideo as String]
        case "audio":
            documentTypes = [kUTTypeAudio as String]
        case "document":
            documentTypes = legacyDocumentTypes()
        case "custom":
            // Map extensions to UTIs; fall back to kUTTypeData if unknown
            if let exts = pending.allowedExtensions, !exts.isEmpty {
                documentTypes = exts.compactMap { ext in
                    UTTypeCreatePreferredIdentifierForTag(
                        kUTTagClassFilenameExtension, ext as CFString, nil
                    )?.takeRetainedValue() as String?
                }
                if documentTypes.isEmpty { documentTypes = [kUTTypeData as String] }
            } else {
                documentTypes = [kUTTypeData as String]
            }
        default: // "all"
            documentTypes = [kUTTypeData as String]
        }

        let picker = UIDocumentPickerViewController(
            documentTypes: documentTypes, in: .import)
        picker.delegate = DocumentPickerDelegate(pending: pending)
        picker.allowsMultipleSelection = pending.allowMultiple
        picker.modalPresentationStyle = .formSheet
        vc.present(picker, animated: true)
    }

    // ─── Image / Video picker ─────────────────────────────────────────────

    private func presentImagePicker(
        sourceType: UIImagePickerController.SourceType,
        from vc: UIViewController,
        pending: PendingCall) {

        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            pending.sendError("SOURCE_NOT_AVAILABLE", "Source type not available")
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType    = sourceType
        picker.mediaTypes    = [imageUTI()]
        picker.delegate      = ImagePickerDelegate(pending: pending, plugin: self)
        picker.allowsEditing = false
        vc.present(picker, animated: true)
    }

    private func presentVideoPicker(
        sourceType: UIImagePickerController.SourceType,
        from vc: UIViewController,
        pending: PendingCall) {

        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            pending.sendError("SOURCE_NOT_AVAILABLE", "Source type not available")
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType    = sourceType
        picker.mediaTypes    = [movieUTI()]
        picker.delegate      = ImagePickerDelegate(pending: pending, plugin: self)
        picker.allowsEditing = false
        picker.videoQuality  = .typeMedium
        vc.present(picker, animated: true)
    }

    // ─── UTI helpers (iOS 14 safe) ────────────────────────────────────────

    private func imageUTI() -> String {
        if #available(iOS 14.0, *) { return UTType.image.identifier }
        return kUTTypeImage as String
    }

    private func movieUTI() -> String {
        if #available(iOS 14.0, *) { return UTType.movie.identifier }
        return kUTTypeMovie as String
    }

    // ─── File processing ──────────────────────────────────────────────────

    func processFile(url: URL, pending: PendingCall) -> [String: Any]? {
        do {
            let resources = try url.resourceValues(
                forKeys: [.fileSizeKey, .typeIdentifierKey, .localizedNameKey])
            let fileName = resources.localizedName ?? url.lastPathComponent
            let fileSize = resources.fileSize ?? 0
            let mimeType = getMimeType(from: resources.typeIdentifier)

            // Write to a plugin-owned temp location so security-scoped access
            // to the original URL is no longer needed after this point.
            guard let tempURL = createTemporaryFile(from: url, fileName: fileName) else {
                return nil
            }
            // Track for plugin-wide clearTemporaryFiles
            allTemporaryFiles.append(tempURL)

            var fileData: [String: Any] = [
                "path":     tempURL.path,
                "name":     fileName,
                "size":     fileSize,
                "mimeType": mimeType as Any,
                "bytes":    NSNull()
            ]

            if pending.withData {
                // Read from the already-copied tempURL, not the original
                var data = try Data(contentsOf: tempURL)

                if pending.allowCompression,
                   let mime = mimeType, mime.hasPrefix("image/") {
                    data = compressImageData(data, quality: pending.compressionQuality) ?? data
                }

                fileData["bytes"] = FlutterStandardTypedData(bytes: data)
            }

            return fileData
        } catch {
            return nil
        }
    }

    func handleImageSelection(info: [UIImagePickerController.InfoKey: Any],
                              pending: PendingCall) {
        guard let image = info[.originalImage] as? UIImage else {
            pending.sendError("NO_IMAGE", "No image was returned")
            return
        }

        let quality = pending.allowCompression ? pending.compressionQuality : 1.0
        guard let imageData = image.jpegData(compressionQuality: quality) else {
            pending.sendError("IMAGE_ENCODE_ERROR", "Failed to encode image as JPEG")
            return
        }

        let fileName = "image_\(Int(Date().timeIntervalSince1970)).jpg"
        guard let tempURL = saveDataToTemporaryFile(data: imageData, fileName: fileName) else {
            pending.sendError("TEMP_FILE_ERROR", "Failed to create temporary file")
            return
        }
        allTemporaryFiles.append(tempURL)

        var fileData: [String: Any] = [
            "path":     tempURL.path,
            "name":     fileName,
            "size":     imageData.count,
            "mimeType": "image/jpeg",
            "bytes":    NSNull()
        ]

        if pending.withData {
            fileData["bytes"] = FlutterStandardTypedData(bytes: imageData)
        }

        if pending.isCapturePhotoMode {
            pending.isCapturePhotoMode = false
            pending.send(fileData)                // capturePhoto → single Map
        } else {
            pending.send([fileData])              // pickFiles → List<Map>
        }
    }

    func handleVideoSelection(info: [UIImagePickerController.InfoKey: Any],
                              pending: PendingCall) {
        guard let videoURL = info[.mediaURL] as? URL else {
            pending.sendError("NO_VIDEO", "No video URL was returned")
            return
        }
        if let fileData = processFile(url: videoURL, pending: pending) {
            pending.send([fileData])
        } else {
            pending.sendError("VIDEO_PROCESSING_ERROR", "Failed to process the selected video")
        }
    }

    // ─── Temp file helpers ────────────────────────────────────────────────

    private func createTemporaryFile(from sourceURL: URL, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("file_picker")
        do {
            try FileManager.default.createDirectory(
                at: tempDir, withIntermediateDirectories: true)
            let tempURL = tempDir.appendingPathComponent(
                "\(UUID().uuidString)_\(fileName)")
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    private func saveDataToTemporaryFile(data: Data, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("file_picker")
        do {
            try FileManager.default.createDirectory(
                at: tempDir, withIntermediateDirectories: true)
            let tempURL = tempDir.appendingPathComponent(
                "\(UUID().uuidString)_\(fileName)")
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    private func getMimeType(from typeIdentifier: String?) -> String? {
        guard let uti = typeIdentifier else { return nil }
        if #available(iOS 14.0, *) {
            return UTType(uti)?.preferredMIMEType
        }
        return UTTypeCopyPreferredTagWithClass(
            uti as CFString, kUTTagClassMIMEType
        )?.takeRetainedValue() as String?
    }

    private func compressImageData(_ data: Data, quality: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }

    private func clearAllTemporaryFiles() {
        for url in allTemporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        allTemporaryFiles.removeAll()
    }

    // ─── Document UTType lists ────────────────────────────────────────────

    @available(iOS 14.0, *)
    private func documentUTTypes() -> [UTType] {
        var types: [UTType] = [.pdf, .text, .plainText, .html, .json, .xml,
                               .zip, .gzip, .javascript,
                               .image, .jpeg, .png, .gif, .bmp, .tiff, .heic, .heif,
                               .audio, .mp3, .wav, .aiff, .m4a,
                               .movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        let extras: [String] = [
            "com.microsoft.word.doc",
            "org.openxmlformats.wordprocessingml.document",
            "com.microsoft.excel.xls",
            "org.openxmlformats.spreadsheetml.sheet",
            "com.microsoft.powerpoint.ppt",
            "org.openxmlformats.presentationml.presentation",
            "public.rtf", "org.oasis-open.opendocument.text",
            "org.oasis-open.opendocument.spreadsheet",
            "org.oasis-open.opendocument.presentation",
            "com.rarlab.rar-archive", "org.7-zip.7-zip-archive",
            "public.css", "public.yaml",
            "public.php-script", "public.python-script",
            "public.c-source", "public.c-plus-plus-source",
            "com.sun.java-source", "public.shell-script",
            "public.svg-image", "org.webmproject.webp",
            "com.microsoft.ico", "org.xiph.flac", "org.xiph.ogg",
            "public.truetype-ttf-font", "public.opentype-font",
            "org.idpf.epub-container"
        ]
        types += extras.compactMap { UTType($0) }
        types.append(.data)
        return types
    }

    private func legacyDocumentTypes() -> [String] {
        return [
            kUTTypePDF as String,
            kUTTypeText as String, kUTTypePlainText as String, kUTTypeRTF as String,
            kUTTypeHTML as String, kUTTypeJSON as String, kUTTypeXML as String,
            kUTTypeZipArchive as String, kUTTypeGZIP as String,
            "com.microsoft.word.doc",
            "org.openxmlformats.wordprocessingml.document",
            "com.microsoft.excel.xls",
            "org.openxmlformats.spreadsheetml.sheet",
            "com.microsoft.powerpoint.ppt",
            "org.openxmlformats.presentationml.presentation",
            kUTTypeImage as String, kUTTypeJPEG as String, kUTTypePNG as String,
            kUTTypeGIF as String, kUTTypeBMP as String, kUTTypeTIFF as String,
            kUTTypeAudio as String, kUTTypeMP3 as String,
            kUTTypeMovie as String, kUTTypeVideo as String,
            kUTTypeMPEG4 as String, kUTTypeQuickTimeMovie as String,
            kUTTypeData as String
        ]
    }
}

// ─── AlertDismissProxy ────────────────────────────────────────────────────
// Catches iPad popover outside-tap which doesn't fire the .cancel UIAlertAction

private class AlertDismissProxy: NSObject, UIPopoverPresentationControllerDelegate {
    private let onDismiss: () -> Void
    init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

    func popoverPresentationControllerDidDismissPopover(
        _ popoverPresentationController: UIPopoverPresentationController) {
        onDismiss()
    }
}

// ─── DocumentPickerDelegate ───────────────────────────────────────────────
// Each picker presentation creates its own delegate holding the PendingCall.

private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let pending: ImagePickerMasterPlugin.PendingCall
    private weak var plugin: ImagePickerMasterPlugin?

    init(pending: ImagePickerMasterPlugin.PendingCall,
         plugin: ImagePickerMasterPlugin? = nil) {
        self.pending = pending
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        // plugin reference not needed here; processFile is internal
        // We need the plugin to call processFile — use a workaround:
        // DocumentPickerDelegate stores a weak plugin reference from the factory.
        // Since we can't call processFile without plugin, we inline processing:
        var selectedFiles: [[String: Any]] = []
        for url in urls {
            // Inline the same logic as processFile
            guard let resources = try? url.resourceValues(
                forKeys: [.fileSizeKey, .typeIdentifierKey, .localizedNameKey]) else { continue }
            let fileName = resources.localizedName ?? url.lastPathComponent
            let fileSize = resources.fileSize ?? 0
            let mimeType: String?
            if #available(iOS 14.0, *) {
                mimeType = resources.typeIdentifier.flatMap { UTType($0)?.preferredMIMEType }
            } else {
                mimeType = resources.typeIdentifier.flatMap {
                    UTTypeCopyPreferredTagWithClass(
                        $0 as CFString, kUTTagClassMIMEType
                    )?.takeRetainedValue() as String?
                }
            }

            // Copy to temp
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("file_picker")
            try? FileManager.default.createDirectory(
                at: tempDir, withIntermediateDirectories: true)
            let tempURL = tempDir.appendingPathComponent(
                "\(UUID().uuidString)_\(fileName)")
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
            } catch {
                continue
            }

            var fileData: [String: Any] = [
                "path":     tempURL.path,
                "name":     fileName,
                "size":     fileSize,
                "mimeType": mimeType as Any,
                "bytes":    NSNull()
            ]

            if pending.withData {
                if var data = try? Data(contentsOf: tempURL) {
                    if pending.allowCompression,
                       let mime = mimeType, mime.hasPrefix("image/") {
                        data = UIImage(data: data)?
                            .jpegData(compressionQuality: pending.compressionQuality) ?? data
                    }
                    fileData["bytes"] = FlutterStandardTypedData(bytes: data)
                }
            }

            selectedFiles.append(fileData)
        }
        pending.send(selectedFiles.isEmpty ? nil : selectedFiles)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pending.send(nil)
    }
}

// ─── ImagePickerDelegate ──────────────────────────────────────────────────
// Each image/video picker presentation gets its own delegate.

private class ImagePickerDelegate: NSObject,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private let pending: ImagePickerMasterPlugin.PendingCall
    private weak var plugin: ImagePickerMasterPlugin?

    init(pending: ImagePickerMasterPlugin.PendingCall,
         plugin: ImagePickerMasterPlugin) {
        self.pending = pending
        self.plugin  = plugin
    }

    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

        picker.dismiss(animated: true)

        guard let mediaType = info[.mediaType] as? String else {
            pending.sendError("NO_MEDIA_TYPE", "No media type returned")
            return
        }

        // Compare against BOTH the modern UTType identifier and the legacy
        // kUTType constant to handle all iOS versions correctly.
        let isImage: Bool
        let isMovie: Bool
        if #available(iOS 14.0, *) {
            isImage = (mediaType == UTType.image.identifier)
            isMovie = (mediaType == UTType.movie.identifier)
        } else {
            isImage = (mediaType == kUTTypeImage as String)
            isMovie = (mediaType == kUTTypeMovie as String)
        }

        if isImage {
            plugin?.handleImageSelection(info: info, pending: pending)
        } else if isMovie {
            plugin?.handleVideoSelection(info: info, pending: pending)
        } else {
            pending.sendError("UNSUPPORTED_MEDIA_TYPE",
                              "Unsupported media type: \(mediaType)")
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        pending.isCapturePhotoMode = false
        pending.send(nil)
    }
}
