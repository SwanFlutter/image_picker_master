import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers
import AVFoundation

public class ImagePickerMasterPlugin: NSObject, FlutterPlugin, AVCapturePhotoCaptureDelegate {
    private var channel: FlutterMethodChannel?
    private var result: FlutterResult?
    private var allowMultiple = false
    private var fileType = "all"
    private var allowedExtensions: [String]?
    private var withData = false
    private var allowCompression = false
    private var compressionQuality: Double = 0.8
    private var temporaryFiles: [URL] = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "image_picker_master", binaryMessenger: registrar.messenger)
        let instance = ImagePickerMasterPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.result = result

        switch call.method {
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)

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

        case "resizeImageForCropper":
            guard let arguments = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                return
            }
            resizeImageForCropper(arguments: arguments)

        case "cropImageNative":
            guard let arguments = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                return
            }
            cropImageNative(arguments: arguments)

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
            compressionQuality = Double(quality) / 100.0
        }

        DispatchQueue.main.async {
            self.showFilePicker()
        }
    }

    private func showFilePicker() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = allowMultiple

        // Configure file types
        if #available(macOS 11.0, *) {
            openPanel.allowedContentTypes = getContentTypes()
        } else {
            openPanel.allowedFileTypes = getFileTypes()
        }

        openPanel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK {
                self.processSelectedFiles(urls: openPanel.urls)
            } else {
                self.result?(nil)
            }
        }
    }

    @available(macOS 11.0, *)
    private func getContentTypes() -> [UTType] {
        switch fileType {
        case "image":
            return getImageUTTypes()
        case "video":
            return getVideoUTTypes()
        case "audio":
            return getAudioUTTypes()
        case "document":
            return getDocumentUTTypes()
        case "custom":
            if let extensions = allowedExtensions {
                return extensions.compactMap { UTType(filenameExtension: $0) }
            }
            return [.data]
        default:
            return [.data]
        }
    }
    
    @available(macOS 11.0, *)
    private func getImageUTTypes() -> [UTType] {
        var types: [UTType] = [.image, .jpeg, .png, .gif, .bmp, .tiff, .heic]
        
        // Add WebP if available
        if let webpType = UTType("org.webmproject.webp") {
            types.append(webpType)
        }
        
        return types
    }
    
    @available(macOS 11.0, *)
    private func getVideoUTTypes() -> [UTType] {
        var types: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        
        // Add MP4 if available
        if let mp4Type = UTType("public.mpeg-4") {
            types.append(mp4Type)
        }
        
        return types
    }
    
    @available(macOS 11.0, *)
    private func getAudioUTTypes() -> [UTType] {
        var types: [UTType] = [.audio, .mp3, .wav, .aiff, .m4a]
        
        // Add FLAC if available
        if let flacType = UTType("org.xiph.flac") {
            types.append(flacType)
        }
        
        return types
    }
    
    @available(macOS 11.0, *)
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
        if let perlType = UTType("public.perl-script") {
            contentTypes.append(perlType)
        }
        if let rubyType = UTType("public.ruby-script") {
            contentTypes.append(rubyType)
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

    // ─── cropImageNative ──────────────────────────────────────────────────
    // Full native crop+encode pipeline on a background queue.
    // format: "jpeg" | "png" | "webp_lossy" | "webp_lossless"
    // macOS has no built-in WebP encoder — webp_* formats fall back to JPEG.

    private func cropImageNative(arguments: [String: Any]) {
        guard let filePath = arguments["path"] as? String else {
            result?(FlutterError(code: "INVALID_ARGUMENTS",
                                 message: "path is required", details: nil))
            return
        }
        let cropX      = (arguments["cropX"]      as? Double) ?? 0
        let cropY      = (arguments["cropY"]      as? Double) ?? 0
        let cropW      = (arguments["cropW"]      as? Double) ?? 1
        let cropH      = (arguments["cropH"]      as? Double) ?? 1
        let containerW = (arguments["containerW"] as? Double) ?? 1
        let containerH = (arguments["containerH"] as? Double) ?? 1
        let rotation   = (arguments["rotation"]   as? Int)    ?? 0
        let quality    = (arguments["quality"]    as? Int)    ?? 85
        let format     = (arguments["format"]     as? String  ?? "jpeg").lowercased()
        let maxSize    = (arguments["maxSize"]    as? Int)    ?? 1200
        let capturedResult = result

        DispatchQueue.global(qos: .userInitiated).async {
            let fileURL = URL(fileURLWithPath: filePath)

            // ── Step 1: fast thumbnail decode at maxSize via ImageIO ──────
            guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
                DispatchQueue.main.async { capturedResult?(nil) }; return
            }
            let thumbOpts: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: maxSize,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: false,
                kCGImageSourceShouldCacheImmediately: false
            ]
            guard let cgSrc = CGImageSourceCreateThumbnailAtIndex(
                imageSource, 0, thumbOpts as CFDictionary) else {
                DispatchQueue.main.async { capturedResult?(nil) }; return
            }

            // ── Step 2: apply rotation ────────────────────────────────────
            var nsImg = NSImage(cgImage: cgSrc,
                                size: NSSize(width: cgSrc.width, height: cgSrc.height))
            if rotation != 0 {
                let radians = CGFloat(rotation) * .pi / 180
                let newImg = NSImage(size: nsImg.size)
                newImg.lockFocus()
                let t = AffineTransform(translationByX: nsImg.size.width / 2,
                                         byY: nsImg.size.height / 2)
                var r = AffineTransform(rotationByRadians: radians)
                r.prepend(t)
                r.concat()
                nsImg.draw(in: NSRect(x: -nsImg.size.width / 2,
                                       y: -nsImg.size.height / 2,
                                       width:  nsImg.size.width,
                                       height: nsImg.size.height))
                newImg.unlockFocus()
                nsImg = newImg
            }

            let imgW = Double(nsImg.size.width)
            let imgH = Double(nsImg.size.height)

            // ── Step 3: map crop rect from container coords → pixel coords ─
            let imgAspect  = imgW / imgH
            let contAspect = containerW / containerH
            let displayedW: Double; let displayedH: Double
            let offsetX: Double;    let offsetY: Double
            if imgAspect > contAspect {
                displayedW = containerW;  displayedH = containerW / imgAspect
                offsetX = 0;              offsetY = (containerH - displayedH) / 2
            } else {
                displayedH = containerH;  displayedW = containerH * imgAspect
                offsetX = (containerW - displayedW) / 2; offsetY = 0
            }
            let scaleX = imgW / displayedW
            let scaleY = imgH / displayedH
            let px = max(0, (cropX - offsetX) * scaleX)
            let py = max(0, (cropY - offsetY) * scaleY)
            let pw = min(cropW * scaleX, imgW - px)
            let ph = min(cropH * scaleY, imgH - py)

            guard pw > 0, ph > 0,
                  let cgFull = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async { capturedResult?(nil) }; return
            }

            // ── Step 4: crop ──────────────────────────────────────────────
            guard let cgCropped = cgFull.cropping(
                to: CGRect(x: px, y: py, width: pw, height: ph)) else {
                DispatchQueue.main.async { capturedResult?(nil) }; return
            }

            // ── Step 5: encode ────────────────────────────────────────────
            let bitmapRep = NSBitmapImageRep(cgImage: cgCropped)
            let q = Double(quality) / 100.0
            let data: Data?
            let ext: String
            switch format {
            case "png":
                data = bitmapRep.representation(using: .png, properties: [:])
                ext  = "png"
            default: // jpeg | webp_* → JPEG (no native WebP encoder on macOS)
                data = bitmapRep.representation(using: .jpeg,
                                                properties: [.compressionFactor: q])
                ext  = "jpg"
            }
            guard let encoded = data else {
                DispatchQueue.main.async { capturedResult?(nil) }; return
            }

            // ── Step 6: write to cache ────────────────────────────────────
            let outDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("cropper_output")
            do {
                try FileManager.default.createDirectory(
                    at: outDir, withIntermediateDirectories: true)
                let outURL = outDir.appendingPathComponent(
                    "crop_\(UUID().uuidString).\(ext)")
                try encoded.write(to: outURL)
                self.temporaryFiles.append(outURL)
                DispatchQueue.main.async { capturedResult?(outURL.path) }
            } catch {
                DispatchQueue.main.async { capturedResult?(nil) }
            }
        }
    }

    private func getFileTypes() -> [String] {
        switch fileType {
        case "image":
            return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
        case "video":
            return ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm"]
        case "audio":
            return ["mp3", "wav", "aiff", "m4a", "flac", "ogg"]
        case "document":
            return ["pdf", "txt", "rtf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "html", "css", "js", "json", "xml", "csv"]
        case "custom":
            return allowedExtensions ?? []
        default:
            return []
        }
    }

    private func processSelectedFiles(urls: [URL]) {
        var selectedFiles: [[String: Any]] = []

        for url in urls {
            if let fileData = processFile(url: url) {
                selectedFiles.append(fileData)
            }
        }

        result?(selectedFiles.isEmpty ? nil : selectedFiles)
    }

    private func processFile(url: URL) -> [String: Any]? {
        do {
            let resources = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .typeIdentifierKey,
                .localizedNameKey,
                .contentModificationDateKey
            ])

            let fileName = resources.localizedName ?? url.lastPathComponent
            let fileSize = resources.fileSize ?? 0
            let typeIdentifier = resources.typeIdentifier
            let mimeType = getMimeType(from: typeIdentifier)

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
            print("Error processing file: \(error)")
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

        if #available(macOS 11.0, *) {
            return UTType(typeIdentifier)?.preferredMIMEType
        } else {
            return UTTypeCopyPreferredTagWithClass(
                typeIdentifier as CFString,
                kUTTagClassMIMEType
            )?.takeRetainedValue() as String?
        }
    }

    private func compressImageData(_ data: Data) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let compressedData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )

        return compressedData
    }

    private func clearTemporaryFiles() {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
    }

    // ─── resizeImageForCropper ────────────────────────────────────────────
    // Uses CGImageSourceCreateThumbnailAtIndex — macOS native ImageIO path.
    // Decodes only a thumbnail-sized copy; no full-resolution pixel decode.

    private func resizeImageForCropper(arguments: [String: Any]) {
        guard let filePath = arguments["path"] as? String else {
            result?(FlutterError(code: "INVALID_ARGUMENTS",
                                 message: "path is required", details: nil))
            return
        }
        let maxSize = arguments["maxSize"] as? Int ?? 1024
        let capturedResult = result  // capture before async

        DispatchQueue.global(qos: .userInitiated).async {
            let fileURL = URL(fileURLWithPath: filePath)

            // ── Step 1: read dimensions without full decode ───────────────
            guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
                DispatchQueue.main.async { capturedResult?(filePath) }
                return
            }

            let props = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
                as? [CFString: Any]
            let origW = props?[kCGImagePropertyPixelWidth]  as? Int ?? 0
            let origH = props?[kCGImagePropertyPixelHeight] as? Int ?? 0

            if origW <= maxSize && origH <= maxSize && origW > 0 {
                DispatchQueue.main.async { capturedResult?(filePath) }
                return
            }

            // ── Step 2: native thumbnail at maxSize ───────────────────────
            let thumbOpts: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: maxSize,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: false
            ]
            guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(
                imageSource, 0, thumbOpts as CFDictionary) else {
                DispatchQueue.main.async { capturedResult?(filePath) }
                return
            }

            // ── Step 3: encode to JPEG and write to cache ─────────────────
            let nsImage = NSImage(cgImage: cgThumb,
                                  size: NSSize(width: cgThumb.width,
                                               height: cgThumb.height))
            guard let cgFinal = nsImage.cgImage(forProposedRect: nil,
                                                context: nil, hints: nil) else {
                DispatchQueue.main.async { capturedResult?(filePath) }
                return
            }
            let bitmapRep = NSBitmapImageRep(cgImage: cgFinal)
            guard let jpegData = bitmapRep.representation(
                using: .jpeg, properties: [.compressionFactor: 0.85]) else {
                DispatchQueue.main.async { capturedResult?(filePath) }
                return
            }

            let outDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("cropper_preview")
            do {
                try FileManager.default.createDirectory(
                    at: outDir, withIntermediateDirectories: true)
                let outURL = outDir.appendingPathComponent(
                    "preview_\(UUID().uuidString).jpg")
                try jpegData.write(to: outURL)
                self.temporaryFiles.append(outURL)
                DispatchQueue.main.async { capturedResult?(outURL.path) }
            } catch {
                DispatchQueue.main.async { capturedResult?(filePath) }
            }
        }
    }

    private func capturePhoto(arguments: [String: Any]) {
        allowCompression = arguments["allowCompression"] as? Bool ?? false
        withData = arguments["withData"] as? Bool ?? false
        
        if let quality = arguments["compressionQuality"] as? Int {
            compressionQuality = Double(quality) / 100.0
        }
        
        // Check camera permission
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authStatus {
        case .authorized:
            DispatchQueue.main.async {
                self.showCameraCapture()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.showCameraCapture()
                    } else {
                        self.result?(FlutterError(code: "CAMERA_PERMISSION_DENIED", message: "Camera permission denied", details: nil))
                    }
                }
            }
        case .denied, .restricted:
            result?(FlutterError(code: "CAMERA_PERMISSION_DENIED", message: "Camera permission denied", details: nil))
        @unknown default:
            result?(FlutterError(code: "CAMERA_PERMISSION_UNKNOWN", message: "Unknown camera permission status", details: nil))
        }
    }
    
    private func showCameraCapture() {
        // For macOS, we'll use a simple approach with AVCaptureSession
        // This is a basic implementation - in a real app you might want a more sophisticated UI
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            result?(FlutterError(code: "NO_CAMERA", message: "No camera available", details: nil))
            return
        }
        
        do {
            let captureSession = AVCaptureSession()
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            let photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
            
            // Create a simple capture window
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                                styleMask: [.titled, .closable],
                                backing: .buffered,
                                defer: false)
            window.title = "Capture Photo"
            window.center()
            
            let previewView = AVCaptureVideoPreviewView(frame: window.contentView!.bounds)
            previewView.session = captureSession
            window.contentView?.addSubview(previewView)
            
            // Add capture button
            let captureButton = NSButton(frame: NSRect(x: 270, y: 20, width: 100, height: 30))
            captureButton.title = "Capture"
            captureButton.target = self
            captureButton.action = #selector(capturePhotoAction)
            window.contentView?.addSubview(captureButton)
            
            // Store references for later use
            objc_setAssociatedObject(self, "captureSession", captureSession, .OBJC_ASSOCIATION_RETAIN)
            objc_setAssociatedObject(self, "photoOutput", photoOutput, .OBJC_ASSOCIATION_RETAIN)
            objc_setAssociatedObject(self, "captureWindow", window, .OBJC_ASSOCIATION_RETAIN)
            
            window.makeKeyAndOrderFront(nil)
            captureSession.startRunning()
            
        } catch {
            result?(FlutterError(code: "CAMERA_SETUP_ERROR", message: "Failed to setup camera: \(error.localizedDescription)", details: nil))
        }
    }
    
    @objc private func capturePhotoAction() {
        guard let photoOutput = objc_getAssociatedObject(self, "photoOutput") as? AVCapturePhotoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Close the capture window
        if let window = objc_getAssociatedObject(self, "captureWindow") as? NSWindow {
            window.close()
        }
        
        // Stop the capture session
        if let session = objc_getAssociatedObject(self, "captureSession") as? AVCaptureSession {
            session.stopRunning()
        }
        
        if let error = error {
            result?(FlutterError(code: "CAPTURE_ERROR", message: "Failed to capture photo: \(error.localizedDescription)", details: nil))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            result?(FlutterError(code: "NO_IMAGE_DATA", message: "Failed to get image data", details: nil))
            return
        }
        
        let fileName = "photo_\(Date().timeIntervalSince1970).jpg"
        var finalImageData = imageData
        
        // Apply compression if needed
        if allowCompression {
            finalImageData = compressImageData(imageData) ?? imageData
        }
        
        // Save to temporary file
        let tempURL = saveDataToTemporaryFile(data: finalImageData, fileName: fileName)
        
        var fileData: [String: Any] = [
            "path": tempURL.path,
            "name": fileName,
            "size": finalImageData.count,
            "mimeType": "image/jpeg"
        ]
        
        if withData {
            fileData["bytes"] = FlutterStandardTypedData(bytes: finalImageData)
        }
        
        result?(fileData) // Return single file data for capturePhoto
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