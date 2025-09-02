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
            return [.image, .jpeg, .png, .gif, .bmp, .tiff, .heic, .webP]
        case "video":
            return [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi, .mp4]
        case "audio":
            return [.audio, .mp3, .wav, .aiff, .m4a, .flac]
        case "document":
            return [
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
                return extensions.compactMap { UTType(filenameExtension: $0) }
            }
            return [.data]
        default:
            return [.data]
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
            return ["pdf", "txt", "rtf", "doc", "docx", "xls", "xlsx", "ppt", "pptx"]
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
         
         result?([fileData])
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